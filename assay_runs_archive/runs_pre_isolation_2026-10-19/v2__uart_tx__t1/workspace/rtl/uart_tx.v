module uart_tx #(
    parameter CLKS_PER_BIT = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        busy
);
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_r;

    wire bit_done = (clk_cnt == CLKS_PER_BIT - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_r <= 8'h00;
        else if (state == S_IDLE && tx_start)
            data_r <= tx_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            clk_cnt <= 16'd0;
            bit_idx <= 3'd0;
            tx      <= 1'b1;
            busy    <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx    <= 1'b0;
                        busy  <= 1'b1;
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (bit_done) begin
                        clk_cnt <= 16'd0;
                        tx      <= data_r[0];
                        state   <= S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end
                S_DATA: begin
                    if (bit_done) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                            tx      <= data_r[bit_idx + 3'd1];
                        end
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end
                default: begin
                    if (bit_done) begin
                        clk_cnt <= 16'd0;
                        busy    <= 1'b0;
                        state   <= S_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end
            endcase
        end
    end
endmodule
