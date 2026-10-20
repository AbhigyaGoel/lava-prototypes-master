module clock_divider (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] div,
    output wire       clk_out,
    output wire       tick
);
    reg  [7:0] cnt;
    wire [7:0] n_eff = (div < 8'd2) ? 8'd2 : div;
    wire [7:0] last  = n_eff - 8'd1;

    assign tick    = (cnt >= last);
    assign clk_out = (cnt < (n_eff >> 1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 8'd0;
        else if (tick)
            cnt <= 8'd0;
        else
            cnt <= cnt + 8'd1;
    end
endmodule
