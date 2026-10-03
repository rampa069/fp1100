//============================================================================
// FP-1100 - placa principal: E/S del Z80, interrupciones y los dos latches
// con la placa sub
//
// Puertos (se decodifica A15-A5):
//
//   FF00-FF7F  W  slot_exp[slot_sel] = d3-0 (dispositivo del slot; fase 2)
//   FF80       W  mascara: b7 INT2 al sub, b4 INTS, b3 INTD, b2 INTC (RS232),
//                 b1 INTB (IRQ del FDC), b0 INTA (DRQ del FDC)
//   FFA0       W  b0 slot_sel, b1 rom_sel (1 = RAM en 0000-8FFF)
//   FFC0       W  latch main -> sub
//   FF80-FFFF  R  latch sub -> main
//   resto         slots de expansion (fase 2)
//
// Interrupciones: el 74LS148 de la placa da prioridad INTS > INTA > INTB >
// INTC > INTD y pone el vector F0/F2/F4/F6/F8 en el bus durante el ciclo de
// reconocimiento (modo IM 2 con la tabla en FFxx).
//
// INT2 del sub: la hipotesis de trabajo (doc/hardware_fp1100.md, §7 y §11)
// es que INT2 = mascara.b7 AND latch_lleno, con latch_lleno a uno desde que
// el Z80 escribe FFC0 hasta que el sub lee E800. Como INT2 es por flanco en
// el 7801, asi hay un flanco por cada byte que manda el Z80, y solo mientras
// el Z80 lo tiene habilitado. Cubre los dos parches del emulador de Takeda
// sin mirar el PC del sub.
//============================================================================
`default_nettype none

module fp1100_main (
    input  wire        clk,
    input  wire        reset,

    // bus del Z80
    input  wire [15:0] addr,
    input  wire [7:0]  din,
    output reg  [7:0]  dout,
    output wire        dout_oe,
    input  wire        iorq_n,
    input  wire        m1_n,
    input  wire        rd_n,
    input  wire        wr_n,
    output wire        int_n,

    output reg         rom_sel,        // 1: RAM en 0000-8FFF
    output reg         slot_sel,
    output reg  [3:0]  slot_exp0,      // dispositivo elegido en el slot 1
    output reg  [3:0]  slot_exp1,      // ... y en el slot 2
    output wire        io_rd_lvl,      // ciclo de lectura de E/S (nivel)
    output wire        io_wr_lvl,      // ciclo de escritura de E/S (nivel)
    output wire        io_wr_pulse,    // pulso al empezar la escritura

    // placa sub
    output reg  [7:0]  m2s_data,
    output wire        int2,
    input  wire        m2s_rd,         // el sub ha leido el latch
    input  wire [7:0]  s2m_data,
    input  wire        ints,           // PC3 del sub

    // interrupciones de los slots (fase 2)
    input  wire [3:0]  slot_int        // {INTD, INTC, INTB, INTA}
);
    // Ciclos del Z80: un pulso por escritura y por reconocimiento
    wire io_wr = ~iorq_n & m1_n & ~wr_n;
    wire io_rd = ~iorq_n & m1_n & ~rd_n;
    wire int_ack = ~iorq_n & ~m1_n;
    reg  io_wr_d, int_ack_d;
    always @(posedge clk) begin
        io_wr_d   <= io_wr;
        int_ack_d <= int_ack;
    end
    wire io_wr_p   = io_wr & ~io_wr_d;
    assign io_rd_lvl   = io_rd;
    assign io_wr_lvl   = io_wr;
    assign io_wr_pulse = io_wr_p;
    wire int_ack_p = int_ack & ~int_ack_d;      // empieza el reconocimiento
    wire int_ack_f = ~int_ack & int_ack_d;      // termina

    wire sel_ff00 = (addr[15:7] == 9'b1111_1111_0);          // FF00-FF7F
    wire sel_ff80 = (addr[15:5] == 11'b1111_1111_100);
    wire sel_ffa0 = (addr[15:5] == 11'b1111_1111_101);
    wire sel_ffc0 = (addr[15:6] == 10'b1111_1111_11);
    wire sel_lee  = (addr[15:7] == 9'b1111_1111_1);      // FF80-FFFF

    //------------------------------------------------------------------
    // Registros
    //------------------------------------------------------------------
    reg [7:0] mask;
    reg       latch_lleno;

    always @(posedge clk) begin
        if (reset) begin
            mask        <= 8'h00;
            rom_sel     <= 1'b0;
            slot_sel    <= 1'b0;
            m2s_data    <= 8'h00;
            latch_lleno <= 1'b0;
            slot_exp0   <= 4'd0;
            slot_exp1   <= 4'd0;
        end else begin
            if (io_wr_p) begin
                if (sel_ff00) begin
                    if (slot_sel) slot_exp1 <= din[3:0];
                    else          slot_exp0 <= din[3:0];
                end
                if (sel_ff80) mask <= din;
                if (sel_ffa0) begin
                    slot_sel <= din[0];
                    rom_sel  <= din[1];
                end
                if (sel_ffc0) begin
                    m2s_data    <= din;
                    latch_lleno <= 1'b1;
                end
            end
            if (m2s_rd) latch_lleno <= 1'b0;
        end
    end

    // INT2 = bit 7 de la mascara, sin mas: la ROM del Z80 lo pone a 1 y a 0
    // (90h, 10h) cada vez que contesta al sub para darle el flanco, y el sub
    // sondea INTF2 con SKIT. latch_lleno se queda para depuracion.
    assign int2 = mask[7];

    //------------------------------------------------------------------
    // Interrupciones: {INTS, INTD, INTC, INTB, INTA} = bits 4..0
    //------------------------------------------------------------------
    reg [4:0] pendiente;
    reg       ints_d;
    // INTS es de NIVEL: el sub sube PC3 y no lo baja hasta que el Z80 le
    // contesta (INT2), asi que mientras tanto el Z80 vuelve a entrar en la
    // ISR cada vez que habilita interrupciones; asi es como la ROM sobrevive
    // a que el byte llegue con la ISR equivocada instalada. Ademas se
    // retiene el flanco de subida, porque hay pulsos cortos de PC3 (8 us,
    // rutina 0F96 del sub) que el Z80 podria perder en una instruccion larga
    // con la SDRAM parandolo.
    wire [4:0] activa = ({ints | pendiente[4], pendiente[3:0]}) & mask[4:0];

    // Vector y bit servido, por prioridad. Se congelan al empezar el ciclo
    // de reconocimiento: el Z80 lee el vector varios ciclos despues, y la
    // peticion se retira solo al acabar el ciclo.
    reg [7:0] vector_c, vector;
    reg [4:0] servida_c, servida;
    always @* begin
        vector_c  = 8'hFE;
        servida_c = 5'd0;
        if (activa[4])      begin vector_c = 8'hF0; servida_c = 5'b10000; end   // INTS
        else if (activa[0]) begin vector_c = 8'hF2; servida_c = 5'b00001; end   // INTA
        else if (activa[1]) begin vector_c = 8'hF4; servida_c = 5'b00010; end   // INTB
        else if (activa[2]) begin vector_c = 8'hF6; servida_c = 5'b00100; end   // INTC
        else if (activa[3]) begin vector_c = 8'hF8; servida_c = 5'b01000; end   // INTD
    end

    always @(posedge clk) begin
        ints_d <= ints;
        if (reset) begin
            pendiente <= 5'd0;
            vector    <= 8'hFE;
            servida   <= 5'd0;
        end else begin
            if (int_ack_p) begin
                vector  <= vector_c;
                servida <= servida_c;
            end
            // INTS: flanco de subida de PC3 del sub; se borra al servirla
            if (ints & ~ints_d)              pendiente[4] <= 1'b1;
            else if (int_ack_f & servida[4]) pendiente[4] <= 1'b0;
            // Las de los slots son de nivel: las quita el propio dispositivo
            pendiente[3:0] <= slot_int;
        end
    end

    assign int_n = ~|activa;

    //------------------------------------------------------------------
    // Lectura
    //------------------------------------------------------------------
    assign dout_oe = int_ack | (io_rd & sel_lee);
    always @* begin
        if (int_ack) dout = vector;
        else         dout = s2m_data;
    end

endmodule

`default_nettype wire
