module seg7_decoder (
    input  wire [3:0] hex,
    input  wire       blank,
    output wire [6:0] seg
);
    reg [6:0] pat;

    always @(*) begin
        case (hex)
            4'h0: pat = 7'b0111111;
            4'h1: pat = 7'b0000110;
            4'h2: pat = 7'b1011011;
            4'h3: pat = 7'b1001111;
            4'h4: pat = 7'b1100110;
            4'h5: pat = 7'b1101101;
            4'h6: pat = 7'b1111101;
            4'h7: pat = 7'b0000111;
            4'h8: pat = 7'b1111111;
            4'h9: pat = 7'b1101111;
            4'hA: pat = 7'b1110111;
            4'hB: pat = 7'b1111100;
            4'hC: pat = 7'b0111001;
            4'hD: pat = 7'b1011110;
            4'hE: pat = 7'b1111001;
            default: pat = 7'b1110001;
        endcase
    end

    assign seg = blank ? 7'b1111111 : ~pat;
endmodule
