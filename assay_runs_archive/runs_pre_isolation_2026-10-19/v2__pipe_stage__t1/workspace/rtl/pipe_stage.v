module pipe_stage (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    output wire       in_ready,
    input  wire [7:0] in_data,
    output reg        out_valid,
    input  wire       out_ready,
    output reg  [7:0] out_data
);
    reg       skid_valid;
    reg [7:0] skid_data;

    assign in_ready = !skid_valid;

    wire push = in_valid && in_ready;
    wire pop  = out_valid && out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid  <= 1'b0;
            out_data   <= 8'd0;
            skid_valid <= 1'b0;
            skid_data  <= 8'd0;
        end else if (skid_valid) begin
            if (pop) begin
                out_valid  <= 1'b1;
                out_data   <= skid_data;
                skid_valid <= 1'b0;
            end
        end else if (!out_valid || pop) begin
            out_valid <= push;
            if (push)
                out_data <= in_data;
        end else if (push) begin
            skid_valid <= 1'b1;
            skid_data  <= in_data;
        end
    end
endmodule
