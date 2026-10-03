// Sustituto del T80pa para simulacion: el tv80 (Verilog) con su clock
// enable en CEN_p. El T80 de verdad es VHDL y no lo elaboran Icarus ni
// el simulador. Igual que tv80s: avanza un estado T por cada pulso de CEN_p,
// que es lo que el core retiene para parar la CPU.
//
// Como en el T80pa (common/T80/T80pa.vhd), MREQ (y RD) bajan ya en el CEN_n
// de T1 en los ciclos de memoria: el core cuenta desde ahi cuando parar la
// CPU (fp1100.v, pasos_mem). El dato se sigue tomando al final de T2, medio
// estado antes que el T80pa en las lecturas: si aqui llega a tiempo, en el
// T80pa tambien.
`timescale 1ns/1ps
`define TV80DELAY
module T80pa (
    input  wire RESET_n, CLK, CEN_p, CEN_n, WAIT_n, INT_n, NMI_n, BUSRQ_n,
    output wire M1_n,
    output reg  MREQ_n = 1'b1, IORQ_n = 1'b1, RD_n = 1'b1, WR_n = 1'b1,
    output wire RFSH_n, HALT_n, BUSAK_n,
    output wire [15:0] A,
    input  wire [7:0] DI,
    output wire [7:0] DO
);
    wire intcycle_n, no_read, write, iorq;
    reg  [7:0] di_reg;
    wire [6:0] mcycle, tstate;

    tv80_core #(0, 1) core (
        .cen(CEN_p), .m1_n(M1_n), .iorq(iorq), .no_read(no_read), .write(write),
        .rfsh_n(RFSH_n), .halt_n(HALT_n), .wait_n(WAIT_n), .int_n(INT_n),
        .nmi_n(NMI_n), .reset_n(RESET_n), .busrq_n(BUSRQ_n), .busak_n(BUSAK_n),
        .clk(CLK), .IntE(), .stop(), .A(A), .dinst(DI), .di(di_reg), .dout(DO),
        .mc(mcycle), .ts(tstate), .intcycle_n(intcycle_n)
    );

    always @(posedge CLK or negedge RESET_n) begin
        if (!RESET_n) begin
            RD_n <= 1; WR_n <= 1; IORQ_n <= 1; MREQ_n <= 1; di_reg <= 0;
        end else if (CEN_p) begin
            RD_n <= 1; WR_n <= 1; IORQ_n <= 1; MREQ_n <= 1;
            if (mcycle[0]) begin
                if (tstate[1] || (tstate[2] && WAIT_n == 1'b0)) begin
                    RD_n <= ~intcycle_n;
                    MREQ_n <= ~intcycle_n;
                    IORQ_n <= intcycle_n;
                end
            end else begin
                if ((tstate[1] || (tstate[2] && WAIT_n == 1'b0)) && no_read == 1'b0 && write == 1'b0) begin
                    RD_n <= 1'b0;
                    IORQ_n <= ~iorq;
                    MREQ_n <= iorq;
                end
                if ((tstate[1] || (tstate[2] && WAIT_n == 1'b0)) && write == 1'b1) begin
                    WR_n <= 1'b0; IORQ_n <= ~iorq; MREQ_n <= iorq;
                end
            end
            if (tstate[2] && WAIT_n == 1'b1) di_reg <= DI;
        end else if (CEN_n && tstate[1]) begin
            if (mcycle[0]) begin
                if (intcycle_n) begin RD_n <= 1'b0; MREQ_n <= 1'b0; end
            end else if (no_read == 1'b0 && !iorq) begin
                MREQ_n <= 1'b0;
                if (!write) RD_n <= 1'b0;
            end
        end
    end
endmodule
