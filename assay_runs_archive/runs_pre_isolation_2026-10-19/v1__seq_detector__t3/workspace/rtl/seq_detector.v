module seq_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  found
);
    localparam [4:0] IDLE  = 5'b00001,
                     S1    = 5'b00010,
                     S10   = 5'b00100,
                     S101  = 5'b01000,
                     S1011 = 5'b10000;

    reg [4:0] state, next;

    always @(*) begin
        case (state)
            IDLE:    next = din ? S1    : IDLE;
            S1:      next = din ? S1    : S10;
            S10:     next = din ? S101  : IDLE;
            S101:    next = din ? S1011 : S10;
            S1011:   next = din ? S1    : S10;
            default: next = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
        end else begin
            state <= next;
            found <= (next == S1011);
        end
    end
endmodule
