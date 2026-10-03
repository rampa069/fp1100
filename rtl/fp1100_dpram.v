//============================================================================
// FP-1100 - RAM de doble puerto, un solo reloj, salida registrada
//
// Puerto A: lectura y escritura (la CPU sub, clk_a). Puerto B: solo lectura
// (el video, con su propio reloj clk_b). Quartus la infiere en M9K con
// lectura sincrona en los dos puertos.
//============================================================================
`default_nettype none

module fp1100_dpram #(
    parameter AW = 14,
    parameter DW = 8
) (
    input  wire          clk_a,
    input  wire          clk_b,
    input  wire [AW-1:0] a_addr,
    input  wire [DW-1:0] a_din,
    input  wire          a_we,
    output reg  [DW-1:0] a_dout,
    input  wire [AW-1:0] b_addr,
    output reg  [DW-1:0] b_dout
);
    reg [DW-1:0] mem [0:(1<<AW)-1];

    always @(posedge clk_a) begin
        if (a_we) mem[a_addr] <= a_din;
        a_dout <= mem[a_addr];
    end

    always @(posedge clk_b) b_dout <= mem[b_addr];

endmodule

`default_nettype wire
