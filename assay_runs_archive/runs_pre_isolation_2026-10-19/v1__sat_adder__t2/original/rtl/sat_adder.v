module sat_adder (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       sub,
    output wire [7:0] y,
    output wire       sat
);
    wire [7:0] b_eff = sub ? (~b + 8'd1) : b;
    wire [7:0] sum   = a + b_eff;
    wire       ovf   = (a[7] == b[7]) && (sum[7] != a[7]);

    assign sat = ovf;
    assign y   = ovf ? (a[7] ? 8'h80 : 8'h7F) : sum;
endmodule
