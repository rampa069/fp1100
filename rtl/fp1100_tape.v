//============================================================================
// FP-1100 - reproductor de cinta: un WAV cargado en la SDRAM sale como EAR
//
// El fichero entra por data_io (indice 2) a partir de TAPE_BASE (64K: por
// encima de la ROM, por debajo de la RAM en 400000h; caben 4 MB: unos 3
// minutos a 22 kHz y 8 bits, que es como conviene convertir los WAV). Al acabar
// la carga se recorre la cabecera RIFF: se busca el chunk "fmt " (canales,
// frecuencia de muestreo, bits) y el chunk "data" (principio y tamaño),
// saltando cualquier otro (LIST, etc.). Luego, mientras el motor esta
// activo (rele del 7801, PC5) y la cinta no ha llegado al final, se lee una
// muestra a la frecuencia del fichero y EAR = signo de la muestra (8 bits
// sin signo: >= 80h; 16 bits: bit 15 a cero). Solo se mira el primer canal.
//
// La SDRAM se lee por el puerto A (el que el NewBrain usa para el video):
// a_addr / a_rd / a_dout / a_ack.
//============================================================================
`default_nettype none

module fp1100_tape #(
    parameter [23:0] TAPE_BASE = 24'h010000,
    parameter        CLK_HZ    = 32_000_000
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        cargada,        // pulso: fin de la descarga
    input  wire [23:0] tamano,         // bytes descargados
    input  wire        rebobinar,      // pulso
    input  wire        motor,          // PC5 del sub
    input  wire        pausa,          // opcion del menu

    output reg  [23:0] a_addr,
    output reg         a_rd,
    input  wire [15:0] a_dout,        // palabra: el byte lo elige a_addr[0]
    input  wire        a_ack,

    output reg         ear,
    output wire        reproduciendo,
    output wire        lista           // hay cinta cargada y entendida
);
    localparam [3:0] S_IDLE = 0, S_HDR = 1, S_CHUNK = 2, S_FMT = 3, S_SKIP = 4,
                     S_LISTA = 5, S_MUESTRA = 6;

    reg [3:0]  st;
    reg [23:0] pos;             // posicion de lectura (relativa al fichero)
    reg [23:0] fin;             // tamaño del fichero
    reg [23:0] data_ini, data_fin;
    reg [31:0] chunk_size;
    reg [31:0] id;
    reg [4:0]  n;               // bytes leidos del campo actual
    reg [15:0] canales, bits;
    reg [31:0] rate;
    reg [7:0]  bytes_muestra;
    reg [31:0] acc;             // acumulador de la frecuencia de muestreo
    reg        tick;
    reg        lista_r;
    reg [7:0]  ultimo;          // ultimo byte leido (el alto de la muestra)

    assign lista = lista_r;
    assign reproduciendo = (st == S_MUESTRA) & motor & ~pausa;

    // lectura de un byte: a_rd un ciclo, esperar a_ack
    reg leyendo;
    wire byte_ok = leyendo & a_ack;
    wire [7:0] dato = a_addr[0] ? a_dout[15:8] : a_dout[7:0];
    task lee(input [23:0] p);
        begin
            a_addr  <= TAPE_BASE + p;
            a_rd    <= 1'b1;
            leyendo <= 1'b1;
        end
    endtask

    always @(posedge clk) begin
        a_rd <= 1'b0;
        tick <= 1'b0;
        if (byte_ok) leyendo <= 1'b0;

        // frecuencia de muestreo
        if (st == S_MUESTRA && motor && !pausa) begin
            if (acc + rate >= CLK_HZ) begin acc <= acc + rate - CLK_HZ; tick <= 1'b1; end
            else acc <= acc + rate;
        end

        if (reset) begin
            st <= S_IDLE; leyendo <= 1'b0; lista_r <= 1'b0; ear <= 1'b0; acc <= 0;
        end else if (cargada) begin
            fin <= tamano; pos <= 24'd12; st <= S_CHUNK; n <= 0; lista_r <= 1'b0;
            canales <= 16'd1; bits <= 16'd8; rate <= 32'd44100;
        end else if (rebobinar && lista_r) begin
            pos <= data_ini; st <= S_LISTA; acc <= 0;
        end else case (st)
            S_IDLE: ;

            // id (4) + tamaño (4) del chunk
            S_CHUNK: begin
                if (pos + 8 > fin) begin st <= S_IDLE; end
                else if (!leyendo && !a_rd) begin
                    if (n == 8) begin
                        n <= 0;
                        pos <= pos + 8;
                        if (id == 32'h666d7420)      st <= S_FMT;     // "fmt "
                        else if (id == 32'h64617461) begin           // "data"
                            data_ini <= pos + 8;
                            data_fin <= (pos + 8 + chunk_size[23:0] > fin) ? fin : pos + 8 + chunk_size[23:0];
                            bytes_muestra <= (canales[7:0] * bits[7:0]) >> 3;
                            st <= S_LISTA; lista_r <= 1'b1;
                        end else st <= S_SKIP;
                    end else lee(pos + n);
                end else if (byte_ok) begin
                    if (n < 4) id <= {id[23:0], dato};                 // big-endian (ASCII)
                    else chunk_size <= {dato, chunk_size[31:8]};        // little-endian
                    n <= n + 1;
                end
            end

            // fmt: formato(2) canales(2) rate(4) byterate(4) align(2) bits(2)
            S_FMT: begin
                if (!leyendo && !a_rd) begin
                    if (n == 16) begin
                        n <= 0;
                        pos <= pos + chunk_size[23:0] + chunk_size[0];
                        st <= S_CHUNK;
                    end else lee(pos + n);
                end else if (byte_ok) begin
                    case (n)
                        5'd2:  canales[7:0]  <= dato;
                        5'd3:  canales[15:8] <= dato;
                        5'd4:  rate[7:0]     <= dato;
                        5'd5:  rate[15:8]    <= dato;
                        5'd6:  rate[23:16]   <= dato;
                        5'd7:  rate[31:24]   <= dato;
                        5'd14: bits[7:0]     <= dato;
                        5'd15: bits[15:8]    <= dato;
                        default: ;
                    endcase
                    n <= n + 1;
                end
            end

            S_SKIP: begin
                pos <= pos + chunk_size[23:0] + chunk_size[0];
                st <= S_CHUNK;
            end

            // cinta lista, parada
            S_LISTA: begin
                pos <= data_ini;
                acc <= 0;
                st  <= S_MUESTRA;
            end

            // una muestra por tick: se lee el byte alto (el ultimo de la
            // muestra del primer canal)
            S_MUESTRA: begin
                if (tick && !leyendo) begin
                    if (pos + bytes_muestra > data_fin) begin
                        ear <= 1'b0;                          // fin de la cinta
                    end else begin
                        lee(pos + ((bits[7:0] == 8'd16) ? 24'd1 : 24'd0));
                        pos <= pos + bytes_muestra;
                    end
                end else if (byte_ok) begin
                    ultimo <= dato;
                    ear <= (bits[7:0] == 8'd16) ? ~dato[7] : dato[7];
                end
            end
            default: st <= S_IDLE;
        endcase
    end

endmodule

`default_nettype wire
