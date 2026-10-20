module shift_reg (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire       load,
    input  wire       dir,
    input  wire       sin,
    input  wire [7:0] d,
    output reg  [7:0] q,
    output wire       sout
);
    assign sout = dir ? q[0] : q[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 8'd0;
        end else if (en) begin
            if (load)
                q <= d;
            else if (dir)
                q <= {1'b0, q[7:1]};
            else
                q <= {q[6:0], sin};
        end
    end
endmodule
