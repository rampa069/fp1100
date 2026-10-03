//============================================================================
// FP-1100 - teclado PS/2 (el del core NewBrain) recibido por la linea serie de user_io
//
// Por que no se usa key_strobe/key_pressed de user_io: esa interfaz arma
// cada tecla dando por hecho que el firmware manda la secuencia entera (E0,
// F0 y el codigo) en UNA sola transferencia SPI; el estado del prefijo se
// reinicia al empezar cada transferencia. El firmware de la SiDi manda un
// byte por transferencia, asi que el F0 se perdia por el camino y cada
// SOLTAR llegaba como otra PULSACION:
//
//   * dos caracteres por tecla;
//   * y peor, SHIFT, CONTROL y GRAPHICS se quedaban pegados, porque su
//     "soltar" los volvia a apretar: parecia que el juego de caracteres del
//     teclado habia cambiado.
//
// user_io tambien saca el teclado como PS/2 serie, byte a byte, y ahi el
// prefijo nunca se pierde, se trocee como se trocee la SPI. Este modulo lo
// recibe y guarda el estado de E0 y F0 entre bytes.
//
// Salida con el mismo formato que usa fp1100_kbd.v, el de MiSTer:
//   {conmuta, pulsada, extendida, codigo}
// donde `conmuta` cambia de valor con cada tecla (no es un pulso).
//============================================================================
`default_nettype none

module fp1100_ps2 (
    input  wire        clk,
    input  wire        reset,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output reg  [10:0] ps2_key = 11'd0,
    // diagnostico (LED): pulso por cada byte recibido y por cada trama mala
    output reg         rx_byte = 1'b0,
    output reg         rx_error = 1'b0
);
    // sincronizacion y flanco de bajada del reloj PS/2
    reg [2:0] clk_s  = 3'b111;
    reg [1:0] dat_s  = 2'b11;
    always @(posedge clk) begin
        clk_s <= {clk_s[1:0], ps2_clk};
        dat_s <= {dat_s[0], ps2_data};
    end
    wire bajada = clk_s[2] & ~clk_s[1];

    // Trama: inicio (0), 8 bits empezando por el de menos peso, paridad y
    // parada (1). Si pasa mucho sin flancos se empieza de cero, para no
    // quedarse desalineado para siempre por un bit perdido.
    reg [10:0] sr;
    reg [3:0]  nbits;
    reg [15:0] quieto;
    reg        e0, f0;
    // Pausa: el firmware manda E1 14 77 E1 F0 14 F0 77 de golpe al pulsarla y
    // nada al soltarla. Sin tratarlo, el 14 (CTRL) se quedaria pulsado. Tras
    // un E1 se ignora todo hasta el 77 que cierra el grupo; al cerrar el
    // primero (el que no lleva F0) se da una pulsacion de 77h (STOP/CONT en
    // fp1100_kbd) que se suelta sola a los ~130 ms (2^22 ciclos a 32 MHz),
    // lo bastante para que el barrido del teclado del sub la vea.
    reg        e1, e1_f0;
    reg [21:0] pausa_cnt = 22'd0;
    reg        pausa_on  = 1'b0;

    wire [10:0] trama = {dat_s[1], sr[10:1]};

    always @(posedge clk) begin
        if (reset) begin
            nbits  <= 4'd0;
            quieto <= 16'd0;
            e0     <= 1'b0;
            f0     <= 1'b0;
            e1     <= 1'b0;
            e1_f0  <= 1'b0;
            pausa_on <= 1'b0;
        end else begin
            rx_byte  <= 1'b0;
            rx_error <= 1'b0;
            if (bajada) begin
                quieto <= 16'd0;
                sr     <= trama;
                if (nbits == 4'd10) begin
                    nbits <= 4'd0;
                    // trama completa: inicio a 0 y parada a 1
                    rx_byte  <= 1'b1;
                    rx_error <= trama[0] | ~trama[10] | ~^trama[9:1];   // inicio, parada, paridad impar
                    if (!trama[0] && trama[10]) begin
                        if (e1) begin
                            if (trama[8:1] == 8'hF0) e1_f0 <= 1'b1;
                            if (trama[8:1] == 8'h77) begin
                                e1 <= 1'b0;
                                if (!e1_f0) begin
                                    ps2_key   <= {~ps2_key[10], 1'b1, 1'b0, 8'h77};
                                    pausa_on  <= 1'b1;
                                    pausa_cnt <= 22'd0;
                                end
                            end
                        end else case (trama[8:1])
                        8'hE0: e0 <= 1'b1;
                        8'hF0: f0 <= 1'b1;
                        8'hE1: begin e1 <= 1'b1; e1_f0 <= 1'b0; e0 <= 1'b0; f0 <= 1'b0; end
                        default: begin
                            ps2_key <= {~ps2_key[10], ~f0, e0, trama[8:1]};
                            e0 <= 1'b0;
                            f0 <= 1'b0;
                        end
                        endcase
                    end
                end else begin
                    nbits <= nbits + 1'b1;
                end
            end else begin
                if (quieto != 16'hFFFF) begin
                    quieto <= quieto + 1'b1;
                    // ~2 ms sin reloj: se empieza de cero, prefijos incluidos
                    // (el firmware manda E0/F0 y el codigo seguidos, a ~76 us)
                    if (quieto == 16'hFFFE) begin
                        nbits <= 4'd0;
                        e0    <= 1'b0;
                        f0    <= 1'b0;
                    end
                end
                // fin de la pulsacion de Pausa (fuera de los ciclos en que
                // se cierra una trama, para no pisar su ps2_key)
                if (pausa_on) begin
                    if (pausa_cnt != 22'h3FFFFF) pausa_cnt <= pausa_cnt + 22'd1;
                    else begin
                        ps2_key  <= {~ps2_key[10], 1'b0, 1'b0, 8'h77};
                        pausa_on <= 1'b0;
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
