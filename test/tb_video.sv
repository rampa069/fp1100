//============================================================================
// Banco de pruebas de la maquina completa (Verilator --binary --timing)
//
// Carga FP1100.ROM por el mismo camino que data_io, arranca, y cada cierto
// tiempo vuelca la trama visible a un PPM (trama_N.ppm). Traza ademas lo
// que pasa por los latches main<->sub y los registros del CRTC.
//
//   +CICLOS=N   ciclos de sistema a simular (32 MHz)
//   +ROM=fich   fichero de ROM (por defecto ../roms/fp1100.rom)
//============================================================================
`timescale 1ns/1ps

module tb_video;
    reg clk = 0;
    always #15.625 clk = ~clk;          // 32 MHz
    reg clk_pix = 0;
    always #18.5185 clk_pix = ~clk_pix; // 27 MHz

    reg reset = 1, mem_reset = 1;

    // SDRAM
    wire [12:0] SDRAM_A;
    wire [15:0] SDRAM_DQ;
    wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS, SDRAM_CKE;
    wire [1:0] SDRAM_BA;

    // carga
    reg  [23:0] dl_addr = 0;
    reg  [7:0]  dl_data = 0;
    reg         dl_wr = 0, rom1_wr = 0, rom2_wr = 0, cg_wr = 0;
    reg  [11:0] rom_wr_addr = 0;
    wire        sdram_free;

    wire        ce_pix;
    wire [7:0]  R, G, B;
    wire        hs, hs_cs, vs, hb, vb;
    wire        beeper, cmt_motor, cmt_mic, led_shift, led_caps, tape_lista, tape_play, cmt_rec;
    reg         ear_in = 0, tape_externa = 1, tape_cargada = 0;
    reg  [23:0] tape_tamano = 0;
    wire [15:0] dbg_pc, dbg_sub_a;
    wire        dbg_sdram_ready, dbg_int_req, dbg_int_ack;
    reg  [10:0] ps2_key = 0;

    // disquetera
    reg  [1:0]  img_mounted = 2'b00;
    reg  [31:0] img_size = 0;
    wire [31:0] sd_lba;
    wire [1:0]  sd_rd, sd_wr;
    reg         sd_ack = 0;
    reg  [8:0]  sd_buff_addr = 0;
    reg  [7:0]  sd_buff_dout = 0;
    wire [7:0]  sd_buff_din;
    reg         sd_buff_wr = 0;
    wire        fdc_motor;

    fp1100 dut (
        .clk_sys(clk), .clk_pix(clk_pix), .reset(reset), .mem_reset(mem_reset),
        .dip(8'hFD), .vid_libre(1'b0),
        .dl_addr(dl_addr), .dl_data(dl_data), .dl_wr(dl_wr), .sdram_free(sdram_free),
        .rom1_wr(rom1_wr), .rom2_wr(rom2_wr), .cg_wr(cg_wr), .rom_wr_addr(rom_wr_addr),
        .SDRAM_A(SDRAM_A), .SDRAM_DQ(SDRAM_DQ), .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH),
        .SDRAM_nWE(SDRAM_nWE), .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_nRAS(SDRAM_nRAS),
        .SDRAM_nCS(SDRAM_nCS), .SDRAM_BA(SDRAM_BA), .SDRAM_CKE(SDRAM_CKE),
        .ce_pix(ce_pix), .vid_r(R), .vid_g(G), .vid_b(B),
        .vid_hs(hs), .vid_hs_cs(hs_cs), .vid_vs(vs), .vid_hb(hb), .vid_vb(vb),
        .ps2_key(ps2_key), .led_shift(led_shift), .led_caps(led_caps),
        .beeper(beeper), .cmt_motor(cmt_motor), .cmt_mic(cmt_mic),
        .ear_in(ear_in), .tape_externa(tape_externa),
        .tape_cargada(tape_cargada), .tape_tamano(tape_tamano),
        .tape_rebobinar(1'b0), .tape_pausa(1'b0),
        .tape_lista(tape_lista), .tape_play(tape_play),
        .cmt_rec(cmt_rec), .ear_mon(),
        .fdc_enable(1'b1),
        .img_mounted(img_mounted), .img_size(img_size),
        .sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_ack(sd_ack),
        .sd_buff_addr(sd_buff_addr), .sd_buff_dout(sd_buff_dout),
        .sd_buff_din(sd_buff_din), .sd_buff_wr(sd_buff_wr),
        .fdc_motor(fdc_motor),
        .dbg_pc(dbg_pc), .dbg_sub_a(dbg_sub_a), .dbg_sdram_ready(dbg_sdram_ready),
        .dbg_int_req(dbg_int_req), .dbg_int_ack(dbg_int_ack)
    );

    sdram_model sdram (
        .clk(clk), .A(SDRAM_A), .DQ(SDRAM_DQ), .DQML(SDRAM_DQML), .DQMH(SDRAM_DQMH),
        .nWE(SDRAM_nWE), .nCAS(SDRAM_nCAS), .nRAS(SDRAM_nRAS), .nCS(SDRAM_nCS),
        .BA(SDRAM_BA), .CKE(SDRAM_CKE)
    );

    //------------------------------------------------------------------
    // Carga de la ROM (48K): igual que data_io, un byte cuando sdram_free
    //------------------------------------------------------------------
    reg [7:0] rom [0:49151];
    integer i, fd, n;
    string romfile;
    longint ciclos, t0, t1;

    task cargar;
        begin
            for (i = 0; i < 49152; i = i + 1) begin
                @(posedge clk);
                if (i < 'h9000) begin
                    while (!sdram_free) @(posedge clk);
                    dl_addr <= i; dl_data <= rom[i]; dl_wr <= 1;
                    @(posedge clk); dl_wr <= 0;
                end else begin
                    rom_wr_addr <= i[11:0]; dl_data <= rom[i];
                    rom1_wr <= (i[15:12] == 4'h9);
                    rom2_wr <= (i[15:12] == 4'hA);
                    cg_wr   <= (i[15:12] == 4'hB);
                    @(posedge clk);
                    rom1_wr <= 0; rom2_wr <= 0; cg_wr <= 0;
                end
            end
        end
    endtask


    //------------------------------------------------------------------
    // mist_video como en el top, y medida de la salida
    //------------------------------------------------------------------
    integer sd_off;
    wire [5:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS;
    reg  sd_disable = 0;
    mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(11), .USE_BLANKS(1'b1), .OSD_COLOR(3'b001), .OUT_COLOR_DEPTH(6), .BIG_OSD(1'b1)) mv (
        .clk_sys(clk_pix), .SPI_SCK(1'b0), .SPI_SS3(1'b1), .SPI_DI(1'b0),
        .R(R), .G(G), .B(B), .HBlank(hb), .VBlank(vb),
        .HSync(sd_disable ? ~hs_cs : ~hs), .VSync(~vs),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_VS(VGA_VS), .VGA_HS(VGA_HS),
        .ce_divider(3'd1), .scandoubler_disable(sd_disable), .no_csync(1'b0), .scanlines(2'b00), .ypbpr(1'b0));

    // periodo de VGA_HS y posicion del primer pixel no negro de cada linea
    longint t_vhs = 0; integer vhs_n = 0, vhs_malos = 0; reg vhs_d = 1;
    integer px_lin = 0, primer = -1, primer_ant = -1, saltos = 0;
    always @(posedge clk_pix) begin
        vhs_d <= VGA_HS;
        if (~VGA_HS & vhs_d) begin
            if (t_vhs != 0 && (($time - t_vhs) > (sd_disable ? 64010000 : 32010000) || ($time - t_vhs) < (sd_disable ? 63990000 : 31990000))) begin
                vhs_malos = vhs_malos + 1;
                if (vhs_malos < 6) $display("%0t VGA_HS periodo %0d ps", $time, $time - t_vhs);
            end
            t_vhs = $time; vhs_n = vhs_n + 1;
            if (primer >= 0 && primer_ant >= 0 && primer != primer_ant) begin
                saltos = saltos + 1;
                if (saltos < 6) $display("%0t primer pixel en %0d (antes %0d)", $time, primer, primer_ant);
            end
            if (primer >= 0) primer_ant = primer;
            primer = -1; px_lin = 0;
        end else begin
            px_lin = px_lin + 1;
            if (primer < 0 && (VGA_R != 0 || VGA_G != 0 || VGA_B != 0)) primer = px_lin;
        end
    end

    initial begin
        if (!$value$plusargs("ROM=%s", romfile)) romfile = "../roms/fp1100.rom";
        if (!$value$plusargs("CICLOS=%d", ciclos)) ciclos = 12000000;
        if ($value$plusargs("SD_OFF=%d", sd_off)) sd_disable = sd_off[0];
        t0 = 0; t1 = 0;
        fd = $fopen(romfile, "rb"); n = $fread(rom, fd); $fclose(fd);
        repeat (10) @(posedge clk); mem_reset = 0;
        repeat (20000) @(posedge clk);
        cargar();
        repeat (100) @(posedge clk); reset = 0;
        repeat (ciclos) @(posedge clk);
        $display("VGA_HS: %0d lineas, %0d con periodo raro; primer pixel cambio %0d veces", vhs_n, vhs_malos, saltos);
        $finish;
    end
endmodule
