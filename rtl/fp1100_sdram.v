//============================================================================
// FP-1100 - controlador de SDRAM (el del core NewBrain, sin cambios)
//
// Aloja la ROM del sistema, la ROM de la controladora de disco y toda la RAM,
// que con la paginacion del modulo de expansion llega a 2 MB y no cabe de
// ninguna forma en block RAM. Ver doc/05-memoria.md y doc/08-sdram.md
//
// Tres puertos con arbitraje por prioridad fija:
//
//     refresco  >  V (VRAM para el video)  >  A (cinta)  >  B (CPU)
//
// El puerto V lee DOS palabras seguidas de la misma fila con un solo
// ACTIVE (READ sin precarga + READ con precarga automatica): los tres planos
// de un byte de VRAM, que se guardan juntos (ver fp1100.v). El puerto B
// admite ademas escrituras de palabra entera (b_w16), para el borrado de
// VRAM por hardware.
//
// El video tiene plazo duro y la CPU no: si a la CPU le toca esperar se le
// quitan los clock enables y se acabo. El refresco va el primero porque
// cuesta un 3% del ancho de banda y no tenerlo pierde datos.
//
// Presupuesto del video (VRAM_SDRAM), por linea del CRTC: 128 caracteres de
// 8 puntos a 16 MHz = 64 us = 2048 ciclos de 32 MHz (261 lineas, 59,8 Hz).
// fp1100_vfetch pide como mucho 80 lecturas V de ~11 ciclos (ACTIVE, dos
// READ separados dos ciclos, CAS 2, tRP) mas el de ida y vuelta: ~1040
// ciclos, el 51% de la linea, y solo en las 200 lineas visibles. El resto queda para refresco (7
// ciclos cada 250), cinta y CPU. La lectura de una linea tiene toda la
// linea de plazo: se dibuja en la siguiente.
//
// Geometria del chip de la Calypso: 8 MB = 64 Mbit organizados como
//
//     4096 filas x 256 columnas x 4 bancos x 16 bits
//
// o sea filas de 12 bits, columnas de 8 y banco en las dos siguientes:
//
//     direccion de byte -> palabra = addr[23:1], byte = addr[0]
//     columna = palabra[7:0]   fila = palabra[19:8]   banco = palabra[21:20]
//
// Cada banco cubre 2 MB. Antes esto describia un chip de 128 Mbit, con filas
// de 13 bits, y la fila 4096 se plegaba sobre la 0: la RAM machacaba la ROM.
//============================================================================
`default_nettype none

module fp1100_sdram #(
    parameter CLK_HZ = 32_000_000
) (
    input  wire        clk,
    input  wire        reset,

    // pines
    output reg  [12:0] SDRAM_A,
    inout  wire [15:0] SDRAM_DQ,
    output reg         SDRAM_DQML,
    output reg         SDRAM_DQMH,
    output wire        SDRAM_nWE,
    output wire        SDRAM_nCAS,
    output wire        SDRAM_nRAS,
    output wire        SDRAM_nCS,
    output reg  [1:0]  SDRAM_BA,
    output wire        SDRAM_CKE,

    // puerto A: video. Se lleva la palabra de 16 bits entera, que son dos
    // caracteres consecutivos. Prioridad sobre la CPU.
    input  wire [23:0] a_addr,
    input  wire        a_rd,
    output reg  [15:0] a_dout,
    output reg         a_ack,

    // puerto V: VRAM para el video. Lee las palabras addr y addr+2 (addr
    // multiplo de 4) y las devuelve juntas: {addr+2, addr}.
    input  wire [23:0] v_addr,
    input  wire        v_rd,
    input  wire        v_par,          // 1: la segunda palabra es addr+4 (no addr+2)
    output reg  [31:0] v_dout,
    output reg         v_ack,

    // puerto B: CPU y carga desde SD. Acceso de byte, o de palabra con b_w16
    // (b_din16, direccion par).
    input  wire [23:0] b_addr,
    input  wire [7:0]  b_din,
    input  wire        b_w16,
    input  wire [15:0] b_din16,
    input  wire        b_rd,
    input  wire        b_wr,
    output reg  [7:0]  b_dout,
    output reg         b_ack,
    output wire        b_free,

    // 1 = recoger el dato de un READ dos ciclos despues de que salga al bus
    // en vez de tres: para placas en las que la SDRAM lo entrega un ciclo
    // antes (la SiDi; ver doc §23-24). Solo mueve la recogida: los comandos
    // y los tiempos de la SDRAM no cambian.
    input  wire        antes
);
    // nCS, nRAS, nCAS, nWE
    localparam CMD_NOP   = 4'b0111;
    localparam CMD_ACT   = 4'b0011;
    localparam CMD_READ  = 4'b0101;
    localparam CMD_WRITE = 4'b0100;
    localparam CMD_PRE   = 4'b0010;
    localparam CMD_REF   = 4'b0001;
    localparam CMD_LMR   = 4'b0000;

    reg [3:0] cmd = CMD_NOP;
    assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = cmd;
    assign SDRAM_CKE = 1'b1;

    reg [15:0] dq_out;
    reg        dq_oe;
    assign SDRAM_DQ = dq_oe ? dq_out : 16'bZ;

    // Lo que llega de la SDRAM se registra en cada ciclo sin nada delante,
    // para que Quartus lo meta en el registro de entrada del propio pin
    // (FAST_INPUT_REGISTER en el .qsf). El reloj de la SDRAM va adelantado
    // 7,8 ns y el dato de CAS 2 se captura en el primer flanco del sistema
    // tras salir: en ese margen no cabian ademas los ~2,8 ns desde el pin
    // hasta un registro dentro de la logica, y el timing no cerraba.
    reg [15:0] dq_in;
    always @(posedge clk) dq_in <= SDRAM_DQ;

    localparam S_INIT = 3'd0, S_IDLE = 3'd1, S_ARB = 3'd2, S_ACT = 3'd3,
               S_RD   = 3'd4, S_WR   = 3'd5, S_REF = 3'd6;

    reg [2:0]  state = S_INIT;
    reg [14:0] wait_cnt;
    reg [4:0]  step;              // la secuencia de arranque llega a 20

    // Peticiones retenidas, una por puerto
    reg [23:0] a_hold_addr;
    reg        a_hold;
    reg [23:0] b_hold_addr;
    reg [7:0]  b_hold_data;
    reg        b_hold, b_hold_wr;
    reg        b_hold_w16;
    reg [15:0] b_hold_d16;
    reg [23:0] v_hold_addr;
    reg        v_hold, v_hold_par;

    // Peticion en curso
    reg [23:0] req_addr;
    reg [7:0]  req_data;
    reg        req_is_wr;
    reg        req_is_a;
    reg        req_is_v, req_v_par;
    reg        req_w16;
    reg [15:0] req_d16;
    reg [15:0] v_lo;

    wire [22:0] word = req_addr[23:1];
    wire [7:0]  col  = word[7:0];
    wire [11:0] row  = word[19:8];
    wire [1:0]  bank = word[21:20];

    // B solo acepta cuando no tiene nada retenido: asi se acompasa data_io
    assign b_free = (state != S_INIT) && !b_hold;

    // Refresco: 8192 filas cada 64 ms -> una cada 7,8 us
    localparam [14:0] INIT_WAIT = CLK_HZ / 10000;   // 100 us
    localparam REF_DIV = CLK_HZ / 128_000;
    reg [9:0] ref_cnt;
    reg       ref_due;

    wire [4:0] paso_dato = antes ? 5'd2 : 5'd3;

    always @(posedge clk) begin
        a_ack <= 1'b0;
        b_ack <= 1'b0;
        v_ack <= 1'b0;
        cmd   <= CMD_NOP;
        dq_oe <= 1'b0;

        if (reset) begin
            state      <= S_INIT;
            wait_cnt   <= INIT_WAIT;
            step       <= 5'd0;
            a_hold     <= 1'b0;
            b_hold     <= 1'b0;
            v_hold     <= 1'b0;
            ref_cnt    <= 10'd0;
            ref_due    <= 1'b0;
            SDRAM_DQML <= 1'b1;
            SDRAM_DQMH <= 1'b1;
        end else begin
            if (ref_cnt >= REF_DIV[9:0] - 1) begin
                ref_cnt <= 10'd0;
                ref_due <= 1'b1;
            end else begin
                ref_cnt <= ref_cnt + 1'b1;
            end

            // Captura de peticiones. Cada puerto retiene la suya hasta que
            // el arbitro le da paso.
            if (a_rd && !a_hold) begin
                a_hold_addr <= a_addr;
                a_hold      <= 1'b1;
            end
            if ((b_rd || b_wr) && !b_hold) begin
                b_hold_addr <= b_addr;
                b_hold_data <= b_din;
                b_hold_wr   <= b_wr;
                b_hold_w16  <= b_w16;
                b_hold_d16  <= b_din16;
                b_hold      <= 1'b1;
            end
            if (v_rd && !v_hold) begin
                v_hold_addr <= v_addr;
                v_hold_par  <= v_par;
                v_hold      <= 1'b1;
            end

            case (state)
            //--------------------------------------------------------------
            S_INIT: begin
                if (wait_cnt != 0) begin
                    wait_cnt <= wait_cnt - 1'b1;
                end else begin
                    step <= step + 1'b1;
                    case (step)
                    5'd0: begin                      // PRECHARGE ALL
                        cmd        <= CMD_PRE;
                        SDRAM_A    <= 13'h0400;      // A10 = 1
                        SDRAM_DQML <= 1'b0;
                        SDRAM_DQMH <= 1'b0;
                    end
                    5'd2:  cmd <= CMD_REF;
                    5'd10: cmd <= CMD_REF;
                    5'd18: begin                     // LOAD MODE REGISTER
                        cmd      <= CMD_LMR;
                        SDRAM_A  <= 13'b000_1_00_010_0_000;  // CAS 2, rafaga 1
                        SDRAM_BA <= 2'b00;
                    end
                    5'd20: begin
                        state <= S_IDLE;
                        step  <= 5'd0;
                    end
                    default: ;
                    endcase
                end
            end

            //--------------------------------------------------------------
            S_IDLE: begin
                step <= 5'd0;
                if (ref_due) begin
                    ref_due <= 1'b0;
                    cmd     <= CMD_REF;
                    state   <= S_REF;
                end else if (v_hold) begin
                    req_addr  <= v_hold_addr;
                    req_v_par <= v_hold_par;
                    req_is_wr <= 1'b0;
                    req_is_a  <= 1'b0;
                    req_is_v  <= 1'b1;
                    state     <= S_ARB;
                end else if (a_hold) begin
                    req_addr  <= a_hold_addr;
                    req_is_wr <= 1'b0;
                    req_is_a  <= 1'b1;
                    req_is_v  <= 1'b0;
                    state     <= S_ARB;
                end else if (b_hold) begin
                    req_addr  <= b_hold_addr;
                    req_data  <= b_hold_data;
                    req_w16   <= b_hold_w16;
                    req_d16   <= b_hold_d16;
                    req_is_wr <= b_hold_wr;
                    req_is_a  <= 1'b0;
                    req_is_v  <= 1'b0;
                    state     <= S_ARB;
                end
            end

            // Un ciclo para que req_addr tome valor antes de calcular la fila
            S_ARB: begin
                cmd      <= CMD_ACT;
                SDRAM_A  <= row;
                SDRAM_BA <= bank;
                state    <= S_ACT;
            end

            //--------------------------------------------------------------
            S_REF: begin
                step <= step + 1'b1;
                if (step == 5'd6) state <= S_IDLE;   // tRFC
            end

            //--------------------------------------------------------------
            S_ACT: begin
                state   <= req_is_wr ? S_WR : S_RD;
                step    <= 5'd0;
                // A10 es el bit de precarga automatica, y va en la posicion 10.
                // Estaba puesto como {4'b0000,1'b1,col}, que deja el uno en A8:
                // nunca se precargaba, la fila se quedaba abierta y el
                // siguiente ACTIVE a otra fila rompia el protocolo.
                // Con V, el primer READ va sin precarga: la lleva el segundo.
                SDRAM_A <= {2'b00, ~req_is_v, 2'b00, col};
                if (req_is_wr) begin
                    cmd        <= CMD_WRITE;
                    dq_out     <= req_w16 ? req_d16 : {req_data, req_data};
                    dq_oe      <= 1'b1;
                    SDRAM_DQML <= req_w16 ? 1'b0 : req_addr[0];    // 0 = habilitado
                    SDRAM_DQMH <= req_w16 ? 1'b0 : ~req_addr[0];
                end else begin
                    cmd        <= CMD_READ;
                    SDRAM_DQML <= 1'b0;
                    SDRAM_DQMH <= 1'b0;
                end
            end

            //--------------------------------------------------------------
            S_RD: begin
                step <= step + 1'b1;
                // V: segundo READ, a la columna siguiente, con precarga. Va
                // DOS ciclos despues del primero, no uno: asi cada palabra se
                // recoge exactamente igual que una lectura suelta (tres
                // ciclos despues de su READ), que es lo que se sabe que
                // funciona en cada placa. Con los dos READ seguidos, en la
                // SiDi la primera palabra llegaba pisada por la segunda (el
                // texto salia cian: el plano verde en el azul y el rojo a
                // cero), aunque en simulacion saliera bien.
                // (se asigna en step 1: el READ sale al bus en step 2; el
                // primero salio en step 0)
                if (req_is_v && step == 5'd1) begin
                    cmd     <= CMD_READ;
                    // columna siguiente, o la de dos mas (v_par: la raster
                    // siguiente en el Screen 1 de 400 lineas; misma fila)
                    SDRAM_A <= req_v_par ? {2'b00, 1'b1, 2'b00, col[7:2], 2'b10}
                                         : {2'b00, 1'b1, 2'b00, col[7:1], 1'b1};
                end
                // Latencia CAS 2: el dato entra en dq_in en el flanco de
                // step 2 y se reparte en el siguiente (el segundo de V, tres
                // despues de su READ). Con 'antes', un paso antes.
                if (req_is_v) begin
                    if (step == paso_dato) v_lo <= dq_in;
                    if (step == paso_dato + 5'd2) begin
                        v_dout <= {dq_in, v_lo};
                        v_ack  <= 1'b1;
                        v_hold <= 1'b0;
                    end
                end else if (step == paso_dato) begin
                    if (req_is_a) begin
                        a_dout <= dq_in;
                        a_ack  <= 1'b1;
                        a_hold <= 1'b0;
                    end else begin
                        b_dout <= req_addr[0] ? dq_in[15:8] : dq_in[7:0];
                        b_ack  <= 1'b1;
                        b_hold <= 1'b0;
                    end
                end
                if (step == (req_is_v ? 5'd6 : 5'd4)) state <= S_IDLE;   // tRP tras la precarga
            end

            //--------------------------------------------------------------
            S_WR: begin
                step <= step + 1'b1;
                if (step == 5'd0) begin
                    b_ack  <= 1'b1;
                    b_hold <= 1'b0;
                end
                if (step == 5'd3) begin
                    SDRAM_DQML <= 1'b0;
                    SDRAM_DQMH <= 1'b0;
                    state      <= S_IDLE;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
