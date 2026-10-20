module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] op,
    output reg  [7:0] y,
    output wire       zero,
    output reg        carry,
    output reg        overflow
);
    localparam OP_ADD = 3'd0, OP_SUB = 3'd1, OP_AND = 3'd2, OP_OR  = 3'd3,
               OP_XOR = 3'd4, OP_SLL = 3'd5, OP_SRL = 3'd6, OP_SLT = 3'd7;

    wire [8:0] sum  = {1'b0, a} + {1'b0, b};
    wire [8:0] diff = {1'b0, a} - {1'b0, b};

    always @(*) begin
        y        = 8'd0;
        carry    = 1'b0;
        overflow = 1'b0;
        case (op)
            OP_ADD: begin
                y        = sum[7:0];
                carry    = sum[8];
                overflow = (a[7] == b[7]) && (sum[7] != a[7]);
            end
            OP_SUB: begin
                y        = diff[7:0];
                carry    = diff[8];
                overflow = (a[7] != b[7]) && (diff[7] != a[7]);
            end
            OP_AND: y = a & b;
            OP_OR:  y = a | b;
            OP_XOR: y = a ^ b;
            OP_SLL: y = a << b[2:0];
            OP_SRL: y = a >> b[2:0];
            OP_SLT: y = {7'd0, ($signed(a) < $signed(b))};
            default: y = 8'd0;
        endcase
    end

    assign zero = (y == 8'd0);
endmodule
