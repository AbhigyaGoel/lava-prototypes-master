module mult_seq (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output reg         busy,
    output reg         done,
    output reg  [15:0] product
);
    // Shift-add signed multiplier: {acc, q} is the partial product register.
    // Each step adds the multiplicand to acc when q[0] is set (subtracts it on the
    // final, sign-bit step), then shifts {acc, q} right arithmetically by one.
    reg  [7:0] mcand;
    reg  [7:0] acc;
    reg  [7:0] q;
    reg  [2:0] cnt;

    wire       last   = (cnt == 3'd7);
    wire [8:0] m_ext  = {mcand[7], mcand};
    wire [7:0] m_neg  = -mcand;
    wire [8:0] addend = !q[0] ? 9'd0 : (last ? {m_neg[7], m_neg} : m_ext);
    wire [8:0] sum    = {acc[7], acc} + addend;

    wire [7:0] acc_nx = sum[8:1];
    wire [7:0] q_nx   = {sum[0], q[7:1]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mcand   <= 8'd0;
            acc     <= 8'd0;
            q       <= 8'd0;
            cnt     <= 3'd0;
            busy    <= 1'b0;
            done    <= 1'b0;
            product <= 16'd0;
        end else begin
            if (start) begin
                done  <= 1'b0;
                mcand <= a;
                q     <= b;
                acc   <= 8'd0;
                cnt   <= 3'd0;
                busy  <= 1'b1;
            end else if (busy) begin
                acc <= acc_nx;
                q   <= q_nx;
                cnt <= cnt + 3'd1;
                if (last) begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    product <= {acc_nx, q_nx};
                end
            end else begin
                done <= 1'b0;
            end
        end
    end
endmodule
