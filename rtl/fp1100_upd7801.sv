//============================================================================
// FP-1100 - uPD7801G: el core uPD7800 de David Hunter (SuperCassetteVision
// para MiSTer, GPL) mas la ROM interna de 4K y la RAM interna de 128 bytes.
//
// Por que no se usa el upd7801.sv que trae el core: sus memorias internas se
// leen de forma combinacional (assign DB = mem[A]), y eso en Cyclone IV no
// cabe en M9K: Quartus lo desharia en miles de LEs. Aqui las dos memorias son
// block RAM sincrona, con el dato un ciclo de sistema despues de la
// direccion. El core no lo nota: la direccion sale en CP1 y el dato se
// captura en CP2, y entre una fase y otra hay 8 ciclos de sistema.
//
// El bus externo (A, DB, RDB, WRB) solo se activa para las direcciones que no
// son internas: 1000-FF7F. Igual que en el chip, que deja el bus en alta
// impedancia cuando accede a su ROM o a su RAM.
//
// Fases: el 7801 corre con un cristal de 4 MHz y hace un ciclo de maquina
// cada 2 MHz, con dos fases. Las cuatro entradas CPx_POSEDGE/NEGEDGE son
// pulsos de un ciclo de sistema, en este orden y repartidos por igual:
//   cp2n -> cp1p -> cp1n -> cp2p   (un ciclo de maquina = 16 ciclos a 32 MHz)
//============================================================================
`default_nettype none

module fp1100_upd7801 (
    input  wire        clk,
    input  wire        cp1p, cp1n, cp2p, cp2n,
    input  wire        reset_n,

    // carga de la ROM interna (sub1.rom) desde data_io
    input  wire        rom_wr,
    input  wire [11:0] rom_wr_addr,
    input  wire [7:0]  rom_wr_data,

    input  wire        int0, int1, int2,
    output wire [15:0] a,
    output wire        a_oe,        // 1: el ciclo va al bus externo
    input  wire [7:0]  db_i,
    output wire [7:0]  db_o,
    output wire        db_oe,
    input  wire        wait_n,
    output wire        m1,
    output wire        rd_n,
    output wire        wr_n,
    output wire [7:0]  pa_o,
    input  wire [7:0]  pb_i,
    output wire [7:0]  pb_o,
    output wire [7:0]  pb_oe,
    input  wire [7:0]  pc_i,
    output wire [7:0]  pc_o,
    output wire [7:0]  pc_oe,
    input  wire        si,
    input  wire        sck,
    output wire        so
);
    wire [15:0] core_a;
    wire [7:0]  core_db_o;
    wire        core_db_oe, core_rd_n, core_wr_n;
    reg  [7:0]  core_db_i;

    // Espacio interno: ROM en 0000-0FFF y RAM en FF80-FFFF
    wire rom_cs  = (core_a[15:12] == 4'h0);
    wire wram_cs = (core_a[15:7] == 9'h1FF);
    wire interno = rom_cs | wram_cs;

    upd7800 core (
        .CLK(clk),
        .CP1_POSEDGE(cp1p), .CP1_NEGEDGE(cp1n),
        .CP2_POSEDGE(cp2p), .CP2_NEGEDGE(cp2n),
        .RESETB(reset_n),
        .INT0(int0), .INT1(int1), .INT2(int2),
        .A(core_a),
        .DB_I(core_db_i), .DB_O(core_db_o), .DB_OE(core_db_oe),
        .WAITB(interno ? 1'b1 : wait_n),
        .M1(m1), .RDB(core_rd_n), .WRB(core_wr_n),
        .PA_O(pa_o),
        .PB_I(pb_i), .PB_O(pb_o), .PB_OE(pb_oe),
        .PC_I(pc_i), .PC_O(pc_o), .PC_OE(pc_oe),
        .SI(si), .SCK(sck), .SO(so)
    );

    // ROM interna, 4K, doble puerto: el core lee y data_io escribe
    reg [7:0] rom [0:4095];
    reg [7:0] rom_q;
    always @(posedge clk) begin
        if (rom_wr) rom[rom_wr_addr] <= rom_wr_data;
        rom_q <= rom[core_a[11:0]];
    end

    // RAM interna, 128 bytes
    reg [7:0] wram [0:127];
    reg [7:0] wram_q;
    always @(posedge clk) begin
        if (wram_cs & ~core_wr_n) wram[core_a[6:0]] <= core_db_o;
        wram_q <= wram[core_a[6:0]];
    end

    always @* begin
        if (rom_cs)       core_db_i = rom_q;
        else if (wram_cs) core_db_i = wram_q;
        else              core_db_i = db_i;
    end

    assign a_oe  = ~interno;
    assign a     = core_a;
    assign db_oe = core_db_oe & a_oe;
    assign db_o  = core_db_o;
    assign rd_n  = core_rd_n | interno;
    assign wr_n  = core_wr_n | interno;

endmodule

`default_nettype wire
