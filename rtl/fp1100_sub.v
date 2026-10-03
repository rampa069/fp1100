//============================================================================
// FP-1100 - placa sub: uPD7801G, sus ROMs, la VRAM, el teclado y los puertos
//
// Mapa del 7801 (ver doc/hardware_fp1100.md):
//
//   0000-0FFF  ROM interna (sub1.rom)             dentro de fp1100_upd7801
//   1000-1FFF  ROM externa (sub2.rom)
//   2000-5FFF  VRAM B  |  6000-9FFF  VRAM R  |  A000-DFFF  VRAM G
//   E000-E3FF  HD46505: a0=0 direccion/estado, a0=1 datos
//   E400-E7FF  W: fila de teclado (b3-0), beeper (b4), habilita teclado (b5)
//              R: DIP switches
//   E800-EBFF  R: latch main->sub   W: latch sub->main
//   EC00-EFFF  W: (MAME: borra INT0; aqui INT0 es de nivel, como en Takeda)
//   F000-F3FF  W: registro de color
//   F000-FF7F  R: generador de caracteres (sub3.rom)
//   FF80-FFFF  RAM interna                         dentro de fp1100_upd7801
//
// Las escrituras en VRAM guardan el dato INVERTIDO (asi lo hace el hardware,
// y el POST lo comprueba). Las lecturas y el video usan lo guardado tal cual.
//
// Mientras HSYNC esta activo el sub no puede tocar la VRAM: se le retiene con
// WAIT hasta que HSYNC cae, como en la maquina. Con la VRAM en block RAM de
// doble puerto no haria falta, pero la ROM del sub cuenta con esos tiempos.
//
// Donde vive la VRAM:
//
//   por defecto    block RAM de doble puerto (48K). El video la lee por el
//                  puerto vf_* (fp1100_vfetch, en clk_sys).
//   VRAM_SDRAM     en la SDRAM, por el puerto vr_* (ver fp1100.v). No cabe
//                  en la SiDi: 48K de VRAM son 48 de sus 66 M9K. El sub se
//                  queda en WAIT hasta que la SDRAM contesta. Cada byte de
//                  VRAM ocupa 4 bytes de SDRAM: {v, plano}, plano B=0 R=1 G=2,
//                  para que el video lea los tres de una vez.
//============================================================================
`default_nettype none

module fp1100_sub (
    input  wire        clk,
    input  wire        reset,
    input  wire        cp1p, cp1n, cp2p, cp2n,   // fases del 7801 (2 MHz)

    // carga de ROMs desde data_io
    input  wire        rom1_wr,        // sub1.rom, interna
    input  wire        rom2_wr,        // sub2.rom
    input  wire        cg_wr,          // sub3.rom, generador de caracteres
    input  wire [11:0] rom_wr_addr,
    input  wire [7:0]  rom_wr_data,

    // comunicacion con la placa principal
    input  wire [7:0]  m2s_data,       // latch main -> sub
    output reg         m2s_rd,         // pulso: el sub ha leido el latch
    output reg  [7:0]  s2m_data,       // latch sub -> main
    output reg         s2m_wr,         // pulso: el sub ha escrito el latch
    input  wire        int2,           // del main (ver fp1100_main)
    output wire        ints,           // PC3: interrupcion al Z80 (nivel)

    // teclado: fila seleccionada -> columnas
    output wire [3:0]  kbd_row,
    input  wire [7:0]  kbd_col,
    output wire        led_shift,
    output wire        led_caps,
    output wire        beeper,
    input  wire [7:0]  dip,

    // CRTC
    output wire        crtc_cs,
    output wire        crtc_a0,
    output wire        crtc_wr,
    output wire [7:0]  crtc_din,
    input  wire [7:0]  crtc_dout,
    input  wire        hsync,

    // hacia el generador de video
    output wire [7:0]  pa,             // puerto A: planos, 40/80, verde, ...
    output reg  [7:0]  color_reg,

    // lectura de VRAM para el video (fp1100_vfetch), solo con block RAM
    input  wire        vf_rd,
    input  wire        vf_par,         // dos direcciones: vf_addr y vf_addr+1
    input  wire [13:0] vf_addr,
    output reg         vf_ack,
    output wire [31:0] vf_q,           // {-, G, R, B}; con vf_par {R1, B1, R0, B0}

    // VRAM en SDRAM (VRAM_SDRAM): peticion de nivel hasta vr_ack
    output reg         vr_req,
    output reg  [15:0] vr_addr,        // {v[13:0], plano[1:0]}
    output reg         vr_wr,
    output reg         vr_w16,         // palabra entera (borrado)
    output reg  [15:0] vr_din,
    input  wire        vr_ack,
    input  wire [7:0]  vr_dout,

    // casete (fase 2)
    output wire        cmt_so,         // SO del 7801: dato serie hacia la cinta
    input  wire        cmt_si,         // dato serie desde la cinta (PC7)
    input  wire        cmt_sck,        // reloj de carga (PC2)
    output wire        cmt_motor,      // PC5

    // depuracion
    output wire [15:0] dbg_a,
    output wire        dbg_m1
);
    //------------------------------------------------------------------
    // CPU
    //------------------------------------------------------------------
    wire [15:0] a;
    wire        a_oe, db_oe, rd_n, wr_n, m1;
    wire [7:0]  db_o;
    reg  [7:0]  db_i;
    wire [7:0]  pa_o, pb_o, pb_oe, pc_o, pc_oe;
    reg  [7:0]  pb_i, pc_i;
    wire        wait_n;

    assign dbg_a  = a;
    assign dbg_m1 = m1;

    fp1100_upd7801 cpu (
        .clk(clk), .cp1p(cp1p), .cp1n(cp1n), .cp2p(cp2p), .cp2n(cp2n),
        .reset_n(~reset),
        .rom_wr(rom1_wr), .rom_wr_addr(rom_wr_addr), .rom_wr_data(rom_wr_data),
        .int0(int0), .int1(1'b0), .int2(int2),
        .a(a), .a_oe(a_oe), .db_i(db_i), .db_o(db_o), .db_oe(db_oe),
        .wait_n(wait_n), .m1(m1), .rd_n(rd_n), .wr_n(wr_n),
        .pa_o(pa_o), .pb_i(pb_i), .pb_o(pb_o), .pb_oe(pb_oe),
        .pc_i(pc_i), .pc_o(pc_o), .pc_oe(pc_oe),
        .si(cmt_si), .sck(cmt_sck), .so(cmt_so)
    );

    // Flancos de RD y WR, para dar UN pulso por ciclo de bus. El dato de
    // salida se registra en el core a la vez que baja WR, asi que se actua
    // un ciclo despues del flanco.
    reg rd_n_d, wr_n_d, rd_p, wr_p;
    always @(posedge clk) begin
        rd_n_d <= rd_n;
        wr_n_d <= wr_n;
        rd_p   <= ~rd_n & rd_n_d;
        wr_p   <= ~wr_n & wr_n_d;
    end

    //------------------------------------------------------------------
    // Decodificado
    //------------------------------------------------------------------
    wire rom2_cs = a_oe & (a[15:12] == 4'h1);
    wire vram_cs = a_oe & (a[15:13] != 3'b000) & (a[15:13] != 3'b111);   // 2000-DFFF
    // Planos: 2000-5FFF B, 6000-9FFF R, A000-DFFF G. No caen en potencias de
    // dos, asi que se calcula la resta y se usan los 14 bits bajos.
    wire [15:0] a_vram = a - 16'h2000;
    wire vram_b_cs = vram_cs & (a_vram[15:14] == 2'd0);
    wire vram_r_cs = vram_cs & (a_vram[15:14] == 2'd1);
    wire vram_g_cs = vram_cs & (a_vram[15:14] == 2'd2);
    wire io_cs   = a_oe & (a[15:12] == 4'hE);
    wire crtc_sel = io_cs & (a[11:10] == 2'd0);
    wire key_sel  = io_cs & (a[11:10] == 2'd1);
    wire comm_sel = io_cs & (a[11:10] == 2'd2);
    wire f_cs    = a_oe & (a[15:12] == 4'hF) & (a[11:7] != 5'h1F);   // F000-FF7F
    wire color_sel = f_cs & (a[11:10] == 2'd0);

    assign crtc_cs  = crtc_sel;
    assign crtc_a0  = a[0];
    assign crtc_wr  = crtc_sel & wr_p;
    assign crtc_din = db_o;

    //------------------------------------------------------------------
    // ROM sub2 y generador de caracteres (block RAM cargada por data_io)
    //------------------------------------------------------------------
    reg [7:0] rom2 [0:4095];
    reg [7:0] rom2_q;
    always @(posedge clk) begin
        if (rom2_wr) rom2[rom_wr_addr] <= rom_wr_data;
        rom2_q <= rom2[a[11:0]];
    end

    reg [7:0] cg [0:4095];
    reg [7:0] cg_q;
    always @(posedge clk) begin
        if (cg_wr) cg[rom_wr_addr] <= rom_wr_data;
        cg_q <= cg[a[11:0]];
    end

    //------------------------------------------------------------------
    // VRAM: 3 planos de 16K
    //------------------------------------------------------------------
    wire [7:0] vram_b_q, vram_r_q, vram_g_q;

    // Borrado de VRAM por hardware: flanco 1->0 de PA5. Cada plano se
    // rellena con FF si el bit de color de fondo correspondiente esta a 1
    // (b4 = B, b5 = R, b6 = G, solo si b7 = 1), o con 00 si no. En block RAM
    // dura 16K ciclos de sistema (medio milisegundo); en SDRAM, 32K
    // escrituras de palabra (unos 8 ms). Mientras tanto el sub espera si
    // intenta entrar en la VRAM.
    reg        pa5_d;
    reg        borrando;
    reg [13:0] borra_addr;
    reg [2:0]  borra_val;      // {G, R, B}
    reg        borra_fase;     // SDRAM: 0 = palabra {R,B}, 1 = palabra {-,G}
    wire       borra_paso;     // un paso del borrado hecho

    always @(posedge clk) begin
        pa5_d <= pa_o[5];
        if (reset) begin
            borrando <= 1'b0;
        end else if (pa5_d & ~pa_o[5] & ~borrando) begin
            borrando   <= 1'b1;
            borra_addr <= 14'd0;
            borra_fase <= 1'b0;
            borra_val  <= color_reg[7] ? color_reg[6:4] : 3'b000;
        end else if (borrando & borra_paso) begin
`ifdef VRAM_SDRAM
            borra_fase <= ~borra_fase;
            if (borra_fase) begin
                borra_addr <= borra_addr + 14'd1;
                if (&borra_addr) borrando <= 1'b0;
            end
`else
            borra_addr <= borra_addr + 14'd1;
            if (&borra_addr) borrando <= 1'b0;
`endif
        end
    end

    wire [1:0] plano = vram_b_cs ? 2'd0 : vram_r_cs ? 2'd1 : 2'd2;

`ifdef VRAM_SDRAM
    //------------------------------------------------------------------
    // En SDRAM. Una peticion cada vez, de nivel hasta vr_ack. La del CPU se
    // lanza cuando RD esta bajo, o WR lleva dos ciclos bajo (el dato ya
    // esta registrado), y vr_hecho la da por servida hasta que RD y WR
    // vuelven a subir. Es de nivel y no de flanco para que un acceso que
    // llega durante el borrado no se pierda: espera y sale al acabar.
    //------------------------------------------------------------------
    reg       vr_hecho;
    reg       vr_de_borra;     // la peticion en curso es del borrado
    reg [7:0] vr_q;
    wire      cpu_vcyc = vram_cs & (~rd_n | (~wr_n & ~wr_n_d));

    assign borra_paso = vr_ack & vr_de_borra;

    always @(posedge clk) begin
        if (reset) begin
            vr_req   <= 1'b0;
            vr_hecho <= 1'b0;
        end else begin
            if (vr_ack) begin
                vr_req <= 1'b0;
                if (!vr_de_borra) begin
                    vr_hecho <= 1'b1;
                    vr_q     <= vr_dout;
                end
            end else if (!vr_req) begin
                if (borrando) begin
                    vr_req  <= 1'b1;
                    vr_de_borra <= 1'b1;
                    vr_addr <= {borra_addr, borra_fase, 1'b0};
                    vr_wr   <= 1'b1;
                    vr_w16  <= 1'b1;
                    vr_din  <= borra_fase ? {8'h00, {8{borra_val[2]}}}
                                          : {{8{borra_val[1]}}, {8{borra_val[0]}}};
                end else if (cpu_vcyc && !vr_hecho) begin
                    vr_req  <= 1'b1;
                    vr_de_borra <= 1'b0;
                    vr_addr <= {a_vram[13:0], plano};
                    vr_wr   <= ~wr_n;
                    vr_w16  <= 1'b0;
                    vr_din  <= {8'h00, ~db_o};      // el dato va invertido
                end
            end
            if (rd_n & wr_n) vr_hecho <= 1'b0;
        end
    end

    assign vram_b_q = vr_q;
    assign vram_r_q = vr_q;
    assign vram_g_q = vr_q;

    always @(posedge clk) vf_ack <= 1'b0;
    assign vf_q = 32'd0;

    // WAIT: HSYNC (como en la maquina), el borrado y la SDRAM
    assign wait_n = ~(vram_cs & (hsync | borrando | ~vr_hecho));

`else
    //------------------------------------------------------------------
    // En block RAM, doble puerto: sub (a) y video (b), los dos en clk
    //------------------------------------------------------------------
    assign borra_paso = 1'b1;

    wire [13:0] wa   = borrando ? borra_addr : a_vram[13:0];
    wire        we_b = borrando | (vram_b_cs & ~wr_n);
    wire        we_r = borrando | (vram_r_cs & ~wr_n);
    wire        we_g = borrando | (vram_g_cs & ~wr_n);
    wire [7:0]  wd   = borrando ? 8'h00 : ~db_o;      // el dato va invertido
    wire [7:0]  wd_b = borrando ? {8{borra_val[0]}} : wd;
    wire [7:0]  wd_r = borrando ? {8{borra_val[1]}} : wd;
    wire [7:0]  wd_g = borrando ? {8{borra_val[2]}} : wd;
    wire [7:0]  vid_b, vid_r, vid_g;

    // vf_par: primero vf_addr y luego vf_addr+1 (par_f1)
    reg         par_f1, par_listo;
    reg  [15:0] par_lo;
    reg  [31:0] par_q;
    wire [13:0] vf_b_addr = par_f1 ? vf_addr + 14'd1 : vf_addr;

    fp1100_dpram #(.AW(14)) vram_b (
        .clk_a(clk), .clk_b(clk),
        .a_addr(wa), .a_din(wd_b), .a_we(we_b), .a_dout(vram_b_q),
        .b_addr(vf_b_addr), .b_dout(vid_b)
    );
    fp1100_dpram #(.AW(14)) vram_r (
        .clk_a(clk), .clk_b(clk),
        .a_addr(wa), .a_din(wd_r), .a_we(we_r), .a_dout(vram_r_q),
        .b_addr(vf_b_addr), .b_dout(vid_r)
    );
    fp1100_dpram #(.AW(14)) vram_g (
        .clk_a(clk), .clk_b(clk),
        .a_addr(wa), .a_din(wd_g), .a_we(we_g), .a_dout(vram_g_q),
        .b_addr(vf_b_addr), .b_dout(vid_g)
    );

    // El dato sale un ciclo despues de la direccion. Con vf_par, tres: la
    // primera direccion, la segunda y el dato junto.
    always @(posedge clk) begin
        vf_ack    <= 1'b0;
        par_f1    <= 1'b0;
        par_listo <= 1'b0;
        if (vf_rd & ~vf_par) vf_ack <= 1'b1;
        if (vf_rd &  vf_par) par_f1 <= 1'b1;
        if (par_f1) begin
            par_lo  <= {vid_r, vid_b};
            vf_ack  <= 1'b1;
            par_listo <= 1'b1;
        end
    end
    // en el ciclo de vf_ack de una peticion par, vid_* ya es de addr+1
    assign vf_q = par_listo ? {vid_r, vid_b, par_lo} : {8'h00, vid_g, vid_r, vid_b};

    always @(posedge clk) begin
        vr_req <= 1'b0; vr_addr <= 16'd0; vr_wr <= 1'b0; vr_w16 <= 1'b0; vr_din <= 16'd0;
    end

    // WAIT: la VRAM esta ocupada durante HSYNC (refresco de la maquina) y
    // durante el borrado
    assign wait_n = ~(vram_cs & (hsync | borrando));
`endif

    //------------------------------------------------------------------
    // Registros de E/S
    //------------------------------------------------------------------
    reg [7:0] key_reg;
    reg       led_shift_r, led_caps_r;

    always @(posedge clk) begin
        m2s_rd <= 1'b0;
        s2m_wr <= 1'b0;
        if (reset) begin
            key_reg     <= 8'h00;
            color_reg   <= 8'h70;
            led_shift_r <= 1'b0;
            led_caps_r  <= 1'b0;
            s2m_data    <= 8'h00;
        end else begin
            if (wr_p) begin
                if (key_sel) begin
                    key_reg <= db_o;
                    // Con el bit 5 a uno, las filas 13/14/15 manejan los LEDs
                    if (db_o[5]) case (db_o[3:0])
                        4'd13: led_shift_r <= 1'b1;
                        4'd14: led_caps_r  <= 1'b1;
                        4'd15: begin led_shift_r <= 1'b0; led_caps_r <= 1'b0; end
                        default: ;
                    endcase
                end
                if (comm_sel) begin
                    s2m_data <= db_o;
                    s2m_wr   <= 1'b1;
                end
                if (color_sel) color_reg <= db_o;
            end
            if (rd_p & comm_sel) m2s_rd <= 1'b1;
        end
    end

    assign kbd_row   = key_reg[3:0];
    assign beeper    = key_reg[4];
    assign led_shift = led_shift_r;
    assign led_caps  = led_caps_r;

    //------------------------------------------------------------------
    // Puertos del 7801
    //------------------------------------------------------------------
    // Puerto A: sale tal cual al video
    assign pa = pa_o;

    // Puerto B: columnas del teclado, solo con el bit 5 del registro a uno
    // (el buffer de tres estados de la linea de datos). La salida es el
    // dato de la Centronics, que aqui no va a ningun sitio.
    always @* pb_i = key_reg[5] ? kbd_col : 8'h00;

    // INT0: bit 7 de la columna leida (fila de las PF, BREAK, STOP). En la
    // placa la linea KI8 va a INT0 sin pasar por el buffer de tres estados,
    // asi que no depende del bit 5; la ROM la mira con SKIT INTF0 justo
    // despues de seleccionar la fila, con el bit 5 a cero (rutina 023E).
    // La escritura en EC00 ("acknowledge of INT0", manual de servicio) no
    // necesita hacer nada aqui: el manejador (0EE2) escribe EC00, espera 4
    // NOPs y vuelve a mirar INTF0 para distinguir un rebote de una tecla
    // pulsada de verdad, y con INT0 de nivel eso sale igual.
    wire int0 = kbd_col[7];

    // Puerto C: b0 BUSY, b1 ERROR (impresora, sin conectar), b2 SCK y b7 SI
    // de la cinta. Los bits de salida se leen tal como se escribieron.
    always @* begin
        pc_i    = pc_o;
        pc_i[0] = 1'b0;
        pc_i[1] = 1'b0;
        pc_i[2] = cmt_sck;
        pc_i[7] = cmt_si;
    end

    assign ints      = pc_o[3];
    assign cmt_motor = pc_o[5];

    //------------------------------------------------------------------
    // Lectura hacia la CPU
    //------------------------------------------------------------------
    always @* begin
        if (rom2_cs)        db_i = rom2_q;
        else if (vram_b_cs) db_i = vram_b_q;
        else if (vram_r_cs) db_i = vram_r_q;
        else if (vram_g_cs) db_i = vram_g_q;
        else if (crtc_sel)  db_i = crtc_dout;
        else if (key_sel)   db_i = dip;
        else if (comm_sel)  db_i = m2s_data;
        else if (color_sel) db_i = 8'hFF;
        else if (f_cs)      db_i = cg_q;
        else                db_i = 8'hFF;
    end

endmodule

`default_nettype wire
