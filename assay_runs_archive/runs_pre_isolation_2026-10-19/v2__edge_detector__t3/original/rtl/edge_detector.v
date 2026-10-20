module edge_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output wire rise,
    output wire fall,
    output wire any
);
    reg sync1, sync2, prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            prev  <= 1'b1;
        end else begin
            sync1 <= din;
            sync2 <= sync1;
            prev  <= sync2;
        end
    end

    assign rise = sync1 & ~sync2;
    assign fall = ~sync2 & prev;
    assign any  = sync2 ^ prev;
endmodule
