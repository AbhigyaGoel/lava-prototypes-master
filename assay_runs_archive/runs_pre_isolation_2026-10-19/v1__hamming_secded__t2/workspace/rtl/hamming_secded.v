module hamming_secded (
    input  wire [12:0] cw,
    output reg  [7:0]  data,
    output reg         single_err,
    output reg         double_err,
    output reg  [3:0]  err_pos
);
    // Codeword layout: cw[0] = overall parity, cw[1], cw[2], cw[4], cw[8] = Hamming parity,
    // data bits d0..d7 at positions 3, 5, 6, 7, 9, 10, 11, 12.
    wire [3:0] syn;
    wire       parity;
    wire [7:0] raw;
    reg  [7:0] flip;

    assign syn[0] = cw[1] ^ cw[3] ^ cw[5] ^ cw[7] ^ cw[9]  ^ cw[11];
    assign syn[1] = cw[2] ^ cw[3] ^ cw[6] ^ cw[7] ^ cw[10] ^ cw[11];
    assign syn[2] = cw[4] ^ cw[5] ^ cw[6] ^ cw[7] ^ cw[12];
    assign syn[3] = cw[8] ^ cw[9] ^ cw[10] ^ cw[11] ^ cw[12];

    assign parity = ^cw;

    assign raw = {cw[12], cw[11], cw[10], cw[9], cw[7], cw[6], cw[5], cw[3]};

    always @(*) begin
        case (syn)
            4'd3:    flip = 8'b0000_0001;
            4'd5:    flip = 8'b0000_0010;
            4'd6:    flip = 8'b0000_0100;
            4'd7:    flip = 8'b0000_1000;
            4'd9:    flip = 8'b0001_0000;
            4'd10:   flip = 8'b0010_0000;
            4'd11:   flip = 8'b0100_0000;
            4'd12:   flip = 8'b1000_0000;
            default: flip = 8'b0000_0000;
        endcase
    end

    wire correctable = parity && (syn == 4'd0 || syn <= 4'd12);

    always @(*) begin
        single_err = correctable;
        double_err = (syn != 4'd0 && !correctable) || (syn > 4'd12 && parity);
        err_pos    = correctable ? syn : 4'd0;
        data       = raw ^ flip;
    end
endmodule
