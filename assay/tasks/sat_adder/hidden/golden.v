module sat_adder (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       sub,
    output wire [7:0] y,
    output wire       sat
);
    wire signed [8:0] a_ext = {a[7], a};
    wire signed [8:0] b_ext = {b[7], b};
    wire signed [8:0] r     = sub ? (a_ext - b_ext) : (a_ext + b_ext);

    wire pos_ovf = (r > 9'sd127);
    wire neg_ovf = (r < -9'sd128);

    assign sat = pos_ovf | neg_ovf;
    assign y   = pos_ovf ? 8'h7F :
                 neg_ovf ? 8'h80 :
                           r[7:0];
endmodule
