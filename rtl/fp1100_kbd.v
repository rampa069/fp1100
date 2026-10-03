//============================================================================
// FP-1100 - teclado: de PS/2 a la matriz de 16 filas x 8 columnas
//
// El sub escribe la fila en E400 (b3-0) y lee las 8 columnas por el puerto
// B. El bit 7 de cada fila (PF0-PF9, BREAK, STOP/CONT) entra ademas por INT0.
//
// La matriz es la del driver de MAME, que coincide con el mapa de Takeda.
// Correspondencia con el teclado de PC (teclas que el FP-1100 no tiene):
//
//   BREAK -> Fin (End)        STOP/CONT -> Pausa         PF0 -> F10
//   (Pausa llega de fp1100_ps2 como una pulsacion de 77h de ~130 ms; Bloq
//   Num tambien es 77h, pero el firmware de MiST no la manda al core)
//   KANA -> Alt izq           GRAPH -> Alt Gr            HOME/CLS -> Inicio
//   INS -> Insert             DEL -> Supr                BS -> Retroceso
//   :* -> '                   ^~ -> =                    @` -> `
//   _ -> tecla 102 (<>)       ¥| -> \                    KP000 y KP, -> (sin tecla)
//
// ps2_key viene con el formato de MiSTer: {conmuta, pulsada, extendida, codigo}
//
// Teclas pegadas, lo que queda cubierto:
//   * Cada SHIFT y cada CTRL del PC se guarda por separado y en la matriz
//     entra su OR: soltar el SHIFT derecho con el izquierdo aun pulsado ya
//     no suelta el SHIFT del FP-1100 (y al reves).
//   * soltar = 1 suelta todas las teclas. El top lo da al abrir y al cerrar
//     el OSD: mientras el OSD esta abierto el firmware no manda el teclado
//     al core, asi que una tecla que se tenia pulsada al abrirlo (SHIFT,
//     por ejemplo) no recibia nunca su "soltar" y se quedaba pegada.
//   * El core pide al firmware que repita la tecla pulsada (FEAT_PS2REP:
//     empieza a ~250 ms y sigue cada ~68 ms; el firmware repite UNA, la
//     ultima pulsada). La ultima tecla pulsada se suelta sola si pasan 600
//     ms sin pulsacion ni repeticion: si su "soltar" se perdio, no se queda
//     pegada, ni siquiera tras una pulsacion corta. Las anteriores (dos
//     teclas a la vez) no se tocan. Con un firmware que no repita, nada
//     cambia (solo se activa al ver la primera repeticion).
//   * Los E0 12 / E0 F0 12 que algunos teclados meten alrededor de las
//     flechas (SHIFT "falso") son extendidos y no estan en la tabla: no
//     tocan el SHIFT. Pausa (E1 ...) lo filtra fp1100_ps2.
//============================================================================
`default_nettype none

module fp1100_kbd (
    input  wire        clk,
    input  wire        reset,
    input  wire [10:0] ps2_key,
    input  wire        soltar,          // soltar todas las teclas
    input  wire        tic_ms,          // pulso cada milisegundo
    output reg         alguna,          // hay alguna tecla pulsada (LED)
    input  wire [3:0]  row,
    output wire [7:0]  col
);
    reg [7:0] matriz [0:15];
    integer i;

    // Fila y bit de cada tecla. 7'h7F = ninguna.
    reg [6:0] pos;        // {fila[3:0], bit[2:0]}
    reg       valida;
    wire      ext  = ps2_key[8];
    wire [7:0] code = ps2_key[7:0];

    always @* begin
        valida = 1'b1;
        pos = 7'h00;
        if (!ext) case (code)
            // fila 1
            8'h12, 8'h59: pos = {4'd1, 3'd0};   // SHIFT
            8'h14: pos = {4'd1, 3'd1};          // CTRL
            8'h58: pos = {4'd1, 3'd3};          // CAPS
            8'h11: pos = {4'd1, 3'd4};          // KANA (Alt izq)
            // fila 2
            8'h1C: pos = {4'd2, 3'd0};          // A
            8'h76: pos = {4'd2, 3'd1};          // ESC
            8'h7B: pos = {4'd2, 3'd2};          // KP-
            8'h15: pos = {4'd2, 3'd3};          // Q
            8'h1A: pos = {4'd2, 3'd4};          // Z
            8'h7C: pos = {4'd2, 3'd5};          // KP*
            8'h09: pos = {4'd2, 3'd7};          // PF0 (F10)
            // fila 3
            8'h1B: pos = {4'd3, 3'd0};          // S
            8'h16: pos = {4'd3, 3'd1};          // 1
            8'h79: pos = {4'd3, 3'd2};          // KP+
            8'h1D: pos = {4'd3, 3'd3};          // W
            8'h22: pos = {4'd3, 3'd4};          // X
            8'h05: pos = {4'd3, 3'd7};          // PF1
            // fila 4
            8'h23: pos = {4'd4, 3'd0};          // D
            8'h1E: pos = {4'd4, 3'd1};          // 2
            8'h7A: pos = {4'd4, 3'd2};          // KP3
            8'h24: pos = {4'd4, 3'd3};          // E
            8'h21: pos = {4'd4, 3'd4};          // C
            8'h71: pos = {4'd4, 3'd6};          // KP.
            8'h06: pos = {4'd4, 3'd7};          // PF2
            // fila 5
            8'h2B: pos = {4'd5, 3'd0};          // F
            8'h26: pos = {4'd5, 3'd1};          // 3
            8'h74: pos = {4'd5, 3'd2};          // KP6
            8'h2D: pos = {4'd5, 3'd3};          // R
            8'h2A: pos = {4'd5, 3'd4};          // V
            8'h04: pos = {4'd5, 3'd7};          // PF3
            // fila 6
            8'h34: pos = {4'd6, 3'd0};          // G
            8'h25: pos = {4'd6, 3'd1};          // 4
            8'h7D: pos = {4'd6, 3'd2};          // KP9
            8'h2C: pos = {4'd6, 3'd3};          // T
            8'h32: pos = {4'd6, 3'd4};          // B
            8'h29: pos = {4'd6, 3'd6};          // SPACE
            8'h0C: pos = {4'd6, 3'd7};          // PF4
            // fila 7
            8'h33: pos = {4'd7, 3'd0};          // H
            8'h2E: pos = {4'd7, 3'd1};          // 5
            8'h75: pos = {4'd7, 3'd2};          // KP8
            8'h35: pos = {4'd7, 3'd3};          // Y
            8'h31: pos = {4'd7, 3'd4};          // N
            8'h70: pos = {4'd7, 3'd6};          // KP0
            8'h03: pos = {4'd7, 3'd7};          // PF5
            // fila 8
            8'h3B: pos = {4'd8, 3'd0};          // J
            8'h36: pos = {4'd8, 3'd1};          // 6
            8'h73: pos = {4'd8, 3'd2};          // KP5
            8'h3C: pos = {4'd8, 3'd3};          // U
            8'h3A: pos = {4'd8, 3'd4};          // M
            8'h72: pos = {4'd8, 3'd6};          // KP2
            8'h0B: pos = {4'd8, 3'd7};          // PF6
            // fila 9
            8'h42: pos = {4'd9, 3'd0};          // K
            8'h3D: pos = {4'd9, 3'd1};          // 7
            8'h6B: pos = {4'd9, 3'd2};          // KP4
            8'h43: pos = {4'd9, 3'd3};          // I
            8'h41: pos = {4'd9, 3'd4};          // , <
            8'h69: pos = {4'd9, 3'd6};          // KP1
            8'h83: pos = {4'd9, 3'd7};          // PF7
            // fila 10
            8'h4B: pos = {4'd10, 3'd0};         // L
            8'h3E: pos = {4'd10, 3'd1};         // 8
            8'h6C: pos = {4'd10, 3'd2};         // KP7
            8'h44: pos = {4'd10, 3'd3};         // O
            8'h49: pos = {4'd10, 3'd4};         // . >
            8'h5B: pos = {4'd10, 3'd6};         // ] }
            8'h0A: pos = {4'd10, 3'd7};         // PF8
            // fila 11
            8'h4C: pos = {4'd11, 3'd0};         // ; +
            8'h46: pos = {4'd11, 3'd1};         // 9
            8'h5A: pos = {4'd11, 3'd2};         // RETURN
            8'h4D: pos = {4'd11, 3'd3};         // P
            8'h4A: pos = {4'd11, 3'd4};         // / ?
            8'h66: pos = {4'd11, 3'd5};         // BS
            8'h54: pos = {4'd11, 3'd6};         // [ {
            8'h01: pos = {4'd11, 3'd7};         // PF9
            // fila 12
            8'h52: pos = {4'd12, 3'd0};         // : *   (')
            8'h45: pos = {4'd12, 3'd1};         // 0
            8'h55: pos = {4'd12, 3'd2};         // ^ ~   (=)
            8'h0E: pos = {4'd12, 3'd3};         // @ `   (`)
            8'h61: pos = {4'd12, 3'd4};         // _     (tecla 102)
            8'h5D: pos = {4'd12, 3'd5};         // ¥ |   (\)
            8'h4E: pos = {4'd12, 3'd6};         // - =
            8'h77: pos = {4'd12, 3'd7};         // STOP/CONT (Pausa, ver fp1100_ps2)
            default: valida = 1'b0;
        endcase
        else case (code)
            8'h14: pos = {4'd1, 3'd1};          // CTRL derecho
            8'h11: pos = {4'd1, 3'd2};          // GRAPH (Alt Gr)
            8'h69: pos = {4'd1, 3'd7};          // BREAK (Fin)
            8'h5A: pos = {4'd2, 3'd6};          // ENTER del teclado numerico
            8'h4A: pos = {4'd3, 3'd5};          // KP/
            8'h71: pos = {4'd4, 3'd5};          // DEL (Supr)
            8'h74: pos = {4'd5, 3'd5};          // derecha
            8'h70: pos = {4'd6, 3'd5};          // INS
            8'h72: pos = {4'd7, 3'd5};          // abajo
            8'h75: pos = {4'd8, 3'd5};          // arriba
            8'h6C: pos = {4'd9, 3'd5};          // HOME/CLS (Inicio)
            8'h6B: pos = {4'd10, 3'd5};         // izquierda
            default: valida = 1'b0;
        endcase
    end

    reg conmuta_d;
    reg shift_i, shift_d, ctrl_i, ctrl_d;     // izquierdo / derecho
    wire evento = (ps2_key[10] != conmuta_d);
    // Bloq Mayus: el firmware manda make y break alternos en cada pulsacion
    // (la deja "enclavada") y no la repite: no se vigila.
    // Tampoco las teclas que en USB son modificadores (ALT, ALT GR, WIN): el
    // firmware no las repite.
    wire es_bloq = (!ext && (code == 8'h58 || code == 8'h11)) ||
                   ( ext && (code == 8'h11 || code == 8'h1F || code == 8'h27));
    wire modificador = (!ext && (code == 8'h12 || code == 8'h59 || code == 8'h14)) ||
                       ( ext && code == 8'h14);
    // Ultima tecla pulsada (que no sea modificador): es la que el firmware
    // repite mientras siga pulsada (~250 ms tras pulsarla y luego cada ~68
    // ms). Si pasan 600 ms desde su ultima pulsacion o repeticion sin que
    // llegue nada, se ha perdido su "soltar": se suelta. Solo cuando ya se
    // ha visto alguna repeticion (fw_repite): con un firmware que no repite,
    // nada cambia.
    reg        rep_hay;
    reg [6:0]  rep_pos;
    reg [9:0]  rep_ms;
    reg        fw_repite = 1'b0;
    reg [10:0] silencio_ms = 11'd0;
    // Bloq Mayus (CAPS, fila 1 bit 3) se respeta en la vigilancia global
    wire [7:0] mask_bloq [0:15];
    genvar gm;
    generate for (gm = 0; gm < 16; gm = gm + 1) begin : mb
        assign mask_bloq[gm] = (gm == 1) ? 8'h08 : 8'h00;
    end endgenerate
    reg alguna_sin_bloq;
    integer jb;
    always @* begin
        alguna_sin_bloq = shift_i | shift_d | ctrl_i | ctrl_d;
        for (jb = 0; jb < 16; jb = jb + 1)
            if (|(matriz[jb] & ~mask_bloq[jb])) alguna_sin_bloq = 1'b1;
    end

    always @(posedge clk) begin
        conmuta_d <= ps2_key[10];
        if (reset || soltar) begin
            for (i = 0; i < 16; i = i + 1) matriz[i] <= 8'h00;
            shift_i <= 1'b0; shift_d <= 1'b0; ctrl_i <= 1'b0; ctrl_d <= 1'b0;
            rep_hay <= 1'b0; rep_ms <= 10'd0; silencio_ms <= 11'd0;
        end else begin
            if (evento && valida) begin
                if      (!ext && code == 8'h12) shift_i <= ps2_key[9];
                else if (!ext && code == 8'h59) shift_d <= ps2_key[9];
                else if (!ext && code == 8'h14) ctrl_i  <= ps2_key[9];
                else if ( ext && code == 8'h14) ctrl_d  <= ps2_key[9];
                else matriz[pos[6:3]][pos[2:0]] <= ps2_key[9];
                if (!modificador && !es_bloq) begin
                    if (ps2_key[9]) begin
                        if (matriz[pos[6:3]][pos[2:0]]) fw_repite <= 1'b1;
                        rep_hay <= 1'b1; rep_pos <= pos; rep_ms <= 10'd0;
                    end else if (rep_hay && pos == rep_pos) begin
                        rep_hay <= 1'b0;
                    end
                end
            end
            // Vigilancia global: con el firmware repitiendo, una tecla
            // mantenida de verdad da un evento cada ~68 ms (la ultima
            // pulsada). Si pasan 1,5 s sin NINGUN evento y la matriz sigue
            // con algo pulsado, ese algo es un "soltar" perdido de una tecla
            // que no se vigilaba (un modificador, o una pulsada antes que
            // otra): se suelta todo, salvo Bloq Mayus, que el firmware deja
            // enclavada a proposito. Solo falla si se mantiene SOLO un
            // modificador mas de 1,5 s sin tocar nada mas.
            if (evento) silencio_ms <= 11'd0;
            else if (tic_ms && silencio_ms != 11'h7FF) silencio_ms <= silencio_ms + 11'd1;
            if (fw_repite && silencio_ms >= 11'd1500 && alguna_sin_bloq) begin
                for (i = 0; i < 16; i = i + 1) matriz[i] <= matriz[i] & mask_bloq[i];
                shift_i <= 1'b0; shift_d <= 1'b0; ctrl_i <= 1'b0; ctrl_d <= 1'b0;
                rep_hay <= 1'b0;
                silencio_ms <= 11'd0;
            end
            if (tic_ms && rep_hay) begin
                if (rep_ms != 10'd1023) rep_ms <= rep_ms + 10'd1;
                if (fw_repite && rep_ms >= 10'd600) begin
                    matriz[rep_pos[6:3]][rep_pos[2:0]] <= 1'b0;
                    rep_hay <= 1'b0;
                end
            end
        end
    end

    // alguna tecla pulsada, para el LED de diagnostico
    integer j;
    always @(posedge clk) begin
        alguna <= shift_i | shift_d | ctrl_i | ctrl_d;
        for (j = 0; j < 16; j = j + 1)
            if (|matriz[j]) alguna <= 1'b1;
    end

    // fila 1: bit 0 SHIFT, bit 1 CTRL
    assign col = (row == 4'd1) ? (matriz[1] | {6'd0, ctrl_i | ctrl_d, shift_i | shift_d})
                               : matriz[row];

endmodule

`default_nettype wire
