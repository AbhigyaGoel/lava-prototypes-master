module gray_counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output reg  [3:0] gray
);
    reg  [3:0] bin;
    wire [3:0] bin_next = bin + 4'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin  <= 4'd0;
            gray <= 4'd0;
        end else begin
            bin  <= bin_next;
            gray <= bin_next ^ (bin_next >> 1);
        end
    end
endmodule
