module sat_adder (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       sub,
    output wire [7:0] y,
    output wire       sat
);
    wire signed [8:0] a_ext = {a[7], a};
    wire signed [8:0] b_ext = {b[7], b};
    wire signed [9:0] r     = sub ? (a_ext - b_ext) : (a_ext + b_ext);

    wire gt = (r > 10'sd127);
    wire lt = (r < -10'sd128);

    assign sat = gt || lt;
    assign y   = gt ? 8'h7F : (lt ? 8'h80 : r[7:0]);
endmodule
