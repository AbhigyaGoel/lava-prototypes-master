module mod10_counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire       load,
    input  wire [3:0] d,
    output reg  [3:0] q,
    output wire       co
);
    wire at_max = (q == 4'd9);

    assign co = en & ~load & at_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 4'd0;
        end else if (load) begin
            q <= (d > 4'd9) ? 4'd0 : d;
        end else if (en) begin
            q <= at_max ? 4'd0 : q + 4'd1;
        end
    end
endmodule
