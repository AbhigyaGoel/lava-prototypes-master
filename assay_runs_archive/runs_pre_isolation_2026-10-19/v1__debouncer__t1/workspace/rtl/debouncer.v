module debouncer #(
    parameter N = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    reg [7:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 1'b0;
            cnt  <= 8'd0;
        end else if (din != dout) begin
            cnt <= cnt + 8'd1;
            if (cnt + 8'd1 == N) begin
                dout <= din;
                cnt  <= 8'd0;
            end
        end else begin
            cnt <= 8'd0;
        end
    end
endmodule
