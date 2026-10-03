//============================================================================
// FP-1100 - interfaz de casete (hoja 2 del esquema, abajo a la derecha:
// B16, G21, F21, C16, C15 y el divisor de 76,8 kHz)
//
// Transcripcion puerta a puerta del circuito, siguiendo el modelo de Takeda
// (sub.cpp, update_cmt). Todo va con un reloj de 76,8 kHz (4800 Hz x 16),
// que en la maquina sale de un divisor y aqui de un acumulador sobre los 32
// MHz (3/1250 exacto).
//
// GRABAR: SO del 7801 elige 2400 Hz (1) o 1200 Hz (0) del divisor y eso va
// a la clavija MIC. Con PA7 = 1 (reloj de escritura) el SCK del 7801 es el
// bit clock de 1200 Hz, o de 300 Hz si PA6 = 1.
//
// CARGAR (PA7 = 0): el audio (EAR) entra por dos LS74 (B16) que lo
// sincronizan al reloj y detectan el flanco de subida, que borra el contador
// TC4024 (F21). F21 cuenta 76,8 kHz hasta saturar en 48 (625 us): un
// periodo de 2400 Hz (416 us) no llega, uno de 1200 Hz (833 us) si. En cada
// flanco de subida del audio G21a captura "no saturado" = 2400 Hz = bit 1,
// y la saturacion lo resetea = bit 0: eso es el dato demodulado. G21b lo
// retrasa un reloj; SI = G21a & G21b. El LS93 (C16) cuenta periodos del
// audio desde el ultimo cambio de dato (el XOR de G21a y G21b lo borra) y
// el LS151 (C15) elige con {PA7, PA6, SI} que hace de SCK:
//
//     PA7 PA6 SI   SCK
//      0   0  0    F21 no saturado    (1200 baudios, bit 0)
//      0   0  1    ~QA del LS93       (1200 baudios, bit 1: un ciclo de 2400)
//      0   1  0    QB del LS93        (300 baudios)
//      0   1  1    QC del LS93
//      1   0  x    1200 Hz            (escritura)
//      1   1  x    300 Hz
//
// El 7801 desplaza SI en el flanco de subida de SCK (MC.7 = 1).
//============================================================================
`default_nettype none

module fp1100_cmt (
    input  wire clk,            // 32 MHz
    input  wire reset,
    input  wire pa6,            // 1 = 300 baudios
    input  wire pa7,            // 1 = reloj de escritura
    input  wire so,             // SO del 7801
    input  wire ear,            // audio de entrada, ya en digital
    output reg  sck,            // PC2 / SCK del 7801
    output reg  si,             // PC7 / SI del 7801
    output wire mic,            // audio de salida (FSK)
    output wire ck76,           // pulso de 76,8 kHz (para el reproductor)
    output wire [7:0] dbg_clock
);
    //------------------------------------------------------------------
    // 76,8 kHz: 32 MHz * 3 / 1250
    //------------------------------------------------------------------
    reg [10:0] acc;
    reg        ck;
    always @(posedge clk) begin
        ck <= 1'b0;
        if (reset) acc <= 11'd0;
        else if (acc >= 11'd1247) begin acc <= acc - 11'd1247; ck <= 1'b1; end
        else acc <= acc + 11'd3;
    end
    assign ck76 = ck;

    // Divisor: bit4 = 2400 Hz, bit5 = 1200 Hz, bit7 = 300 Hz
    reg [7:0] div;
    always @(posedge clk) if (reset) div <= 8'd0; else if (ck) div <= div + 8'd1;
    assign dbg_clock = div;
    wire hz2400 = div[4];
    wire hz1200 = div[5];
    wire hz300  = div[7];

    assign mic = so ? hz2400 : hz1200;

    //------------------------------------------------------------------
    // Lado de carga. Cada bloque se evalua en el orden del hardware: los
    // flip-flops con reloj de 76,8 kHz cambian en ck; los que van con el
    // audio, en los flancos del audio (sincronizado a 32 MHz).
    //------------------------------------------------------------------
    reg [2:0] ear_s;
    always @(posedge clk) ear_s <= {ear_s[1:0], ear};
    wire ear_q    = ear_s[1];
    wire ear_sube = ear_s[1] & ~ear_s[2];
    wire ear_baja = ~ear_s[1] & ear_s[2];

    // B16: dos LS74 en cadena con el reloj de 76,8 kHz
    reg b16a, b16b;
    always @(posedge clk) begin
        if (reset) begin b16a <= 1'b0; b16b <= 1'b0; end
        else if (ck) begin b16a <= ear_q; b16b <= b16a; end
    end
    wire f21_clr = b16a & ~b16b;            // flanco de subida del audio, sincronizado

    // F21: TC4024, cuenta ck mientras no esta saturado (Q5 & Q6)
    reg [5:0] f21;
    wire f21_sat = f21[5] & f21[4];         // >= 48
    always @(posedge clk) begin
        if (reset | f21_clr) f21 <= 6'd0;
        else if (ck & ~f21_sat) f21 <= f21 + 6'd1;
    end
    wire no_sat = ~f21_sat;

    // G21a: D = R = no_sat, reloj = audio (flanco de subida)
    reg g21a;
    always @(posedge clk) begin
        if (reset) g21a <= 1'b1;
        else if (~no_sat) g21a <= 1'b0;             // reset asincrono al saturar
        else if (ear_sube) g21a <= 1'b1;            // D = no_sat = 1 aqui
    end

    // G21b: D = G21a, reloj de 76,8 kHz
    reg g21b;
    always @(posedge clk) begin
        if (reset) g21b <= 1'b1;
        else if (ck) g21b <= g21a;
    end

    // C16: LS93. Contador A por los flancos de bajada del audio; contador B
    // por los flancos de bajada de QA. Borrado con G21a ^ G21b.
    reg       qa;
    reg [1:0] qbc;
    reg       qa_d;
    wire      c16_clr = g21a ^ g21b;
    always @(posedge clk) begin
        qa_d <= qa;
        if (reset | c16_clr) begin qa <= 1'b0; qbc <= 2'd0; end
        else begin
            if (ear_baja) qa <= ~qa;
            if (qa_d & ~qa) qbc <= qbc + 2'd1;
        end
    end
    wire qb = qbc[0];
    wire qc = qbc[1];

    // C15: LS151
    wire si_c = g21a & g21b;
    reg  sck_c;
    always @* begin
        case ({pa7, pa6, si_c})
            3'b000: sck_c = no_sat;
            3'b001: sck_c = ~qa;
            3'b010: sck_c = qb;
            3'b011: sck_c = qc;
            3'b100, 3'b101: sck_c = hz1200;
            default:        sck_c = hz300;
        endcase
    end

    always @(posedge clk) begin
        sck <= sck_c;
        si  <= si_c;
    end

endmodule

`default_nettype wire
