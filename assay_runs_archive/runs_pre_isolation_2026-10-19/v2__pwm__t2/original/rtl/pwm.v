module pwm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] duty,
    output wire       pwm_out
);
    reg [7:0] cnt;
    reg [7:0] duty_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt    <= 8'd0;
            duty_q <= 8'd0;
        end else begin
            cnt <= cnt + 8'd1;
            if (cnt == 8'h00)
                duty_q <= duty;
        end
    end

    assign pwm_out = (cnt <= duty_q);
endmodule
