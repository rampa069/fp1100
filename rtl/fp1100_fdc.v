//============================================================================
// FP-1100 - FDC pack (FP-1020FD / FP-1030): uPD765A en un slot de expansion
//
// El pack se decodifica como dispositivo 0 del slot 1 (PSL1): el Z80 lo
// selecciona con OUT FFA0 (b0 = 0) y OUT FF00 (0) y lo reconoce leyendo el
// codigo de dispositivo 04h en IN FF00-FF7F. Una vez seleccionado, cualquier
// puerto por debajo de FF00 va al pack y solo cuentan A2-A0 (fdcpack.cpp de
// Takeda y la propia IPL de la ROM, rutinas 0441-05E0):
//
//   W 0,1   motor
//   W 2,3   TERMINAL COUNT
//   R 4     registro de estado del 765
//   R/W 5   registro de datos (comandos y resultados)
//   R/W 6   registro de datos con DACK: el byte de la fase de ejecucion
//
// DRQ va a INTA (vector F2) e INT a INTB (vector F4). La ROM lee cada byte
// por interrupcion: EI; HALT; la ISR hace IN A,(C) con C = 6. Al acabar la
// cuenta pulsa TC y espera INTB para leer los 7 bytes de resultado.
//
// Disquetes: 5,25" 2D, 40 pistas, 2 caras, 16 sectores de 256 bytes
// (N = 1), 320K. Imagenes EDSK desde la SD (u765 del core NewBrain, con
// DRQ, TC e INT de fase de resultado añadidos). tools/d88toedsk.py
// convierte las imagenes D88 del emulador de Takeda.
//============================================================================
`default_nettype none

module fp1100_fdc (
    input  wire        clk,             // 32 MHz
    input  wire        reset,
    input  wire        enable,          // hay pack (opcion del OSD)

    // seleccion del slot, de fp1100_main
    input  wire        slot_sel,
    input  wire [3:0]  slot_exp0,       // dispositivo elegido en el slot 1

    // bus de E/S del Z80
    input  wire [15:0] addr,
    input  wire [7:0]  din,
    output reg  [7:0]  dout,
    output wire        dout_oe,
    input  wire        io_rd,           // nivel
    input  wire        io_wr,           // nivel
    input  wire        io_wr_p,         // pulso al empezar la escritura

    output wire        inta,            // DRQ
    output wire        intb,            // INT

    // imagenes de disco (user_io)
    input  wire [1:0]  img_mounted,
    input  wire [31:0] img_size,
    output wire [31:0] sd_lba,
    output wire [1:0]  sd_rd,
    output wire [1:0]  sd_wr,
    input  wire        sd_ack,
    input  wire [8:0]  sd_buff_addr,
    input  wire [7:0]  sd_buff_dout,
    output wire [7:0]  sd_buff_din,
    input  wire        sd_buff_wr,

    output wire        motor_led
);
    // El pack esta seleccionado con slot 1 y dispositivo 0
    wire seleccionado = enable & ~slot_sel & (slot_exp0 == 4'd0);
    wire id_sel  = seleccionado & (addr[15:7] == 9'b1111_1111_0);   // FF00-FF7F
    wire reg_sel = seleccionado & (addr[15:8] != 8'hFF);            // 0000-FEFF

    //------------------------------------------------------------------
    // Motor y TC
    //------------------------------------------------------------------
    reg motor;
    reg tc;
    always @(posedge clk) begin
        tc <= 1'b0;
        if (reset) motor <= 1'b0;
        else if (io_wr_p & reg_sel) begin
            if (addr[2:1] == 2'b00) motor <= 1'b1;
            if (addr[2:1] == 2'b01) tc <= 1'b1;
        end
    end
    assign motor_led = motor;

    //------------------------------------------------------------------
    // uPD765A a 8 MHz (ce cada 4 ciclos de 32 MHz)
    //------------------------------------------------------------------
    reg [1:0] div765 = 2'd0;
    always @(posedge clk) div765 <= div765 + 2'd1;
    wire ce765 = (div765 == 2'd0);

    reg [1:0] listo = 2'b00;
    always @(posedge clk) begin
        if (img_mounted[0]) listo[0] <= |img_size;
        if (img_mounted[1]) listo[1] <= |img_size;
    end

    // Puertos 5 y 6 son el registro de datos (a0 = 1); el 4 el de estado
    wire fdc_sel = reg_sel & (addr[2] & (addr[1:0] != 2'b11));   // 4, 5, 6
    wire a0      = addr[0] | addr[1];                              // 5 y 6 -> datos
    wire [7:0] dout765;
    wire       int765, drq765;

    u765 #(.CYCLES(20'd4000)) fdc765 (
        .clk_sys(clk),
        .ce(ce765),
        .reset(reset | ~enable),
        .ready(listo),
        .motor({motor, motor}),
        .available(2'b11),
        .fast(1'b0),
        .a0(a0),
        .nRD(~(fdc_sel & io_rd)),
        .nWR(~(fdc_sel & io_wr)),
        .din(din),
        .dout(dout765),
        .int_o(int765),
        .drq(drq765),
        .tc(tc),
        .img_mounted(img_mounted),
        .img_wp(1'b0),
        .img_size(img_size),
        .sd_lba(sd_lba),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr),
        .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din),
        .sd_buff_wr(sd_buff_wr)
    );

    assign inta = drq765;
    assign intb = int765;

    //------------------------------------------------------------------
    // Lectura
    //------------------------------------------------------------------
    assign dout_oe = io_rd & (id_sel | fdc_sel);
    always @* begin
        if (id_sel) dout = 8'h04;
        else        dout = dout765;
    end

endmodule

`default_nettype wire
