// Sequential unsigned 8-bit / 8-bit restoring divider, one quotient bit per clock.
// A division takes 8 iterations after the start cycle; results are held in
// dedicated output registers that only change when a division completes.
module div_seq (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,       // begin a division (accepted only while idle)
    input  wire       abort,       // cancel the division in progress
    input  wire [7:0] dividend,
    input  wire [7:0] divisor,
    output reg        busy,
    output reg        done,        // one-cycle completion pulse
    output reg  [7:0] quotient,
    output reg  [7:0] remainder,
    output reg        div0         // last division had divisor == 0
);
    // Working registers
    reg [7:0] rem;       // partial remainder
    reg [7:0] quo;       // dividend bits shifting out / quotient bits shifting in
    reg [7:0] dvs;       // captured divisor
    reg [2:0] step;      // iteration index 0..7

    // One restoring step: bring down the next dividend bit, try to subtract the divisor
    wire [8:0] shifted  = {rem, quo[7]};
    wire [8:0] diff     = shifted - {1'b0, dvs};
    wire       take     = !diff[8];
    wire [7:0] rem_next = take ? diff[7:0] : shifted[7:0];
    wire [7:0] quo_next = {quo[6:0], take};
    wire       last_step = (step == 3'd7);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            quotient  <= 8'd0;
            remainder <= 8'd0;
            div0      <= 1'b0;
            rem       <= 8'd0;
            quo       <= 8'd0;
            dvs       <= 8'd0;
            step      <= 3'd0;
        end else begin
            done <= 1'b0;
            if (start) begin
                busy   <= 1'b1;
                rem    <= 8'd0;
                quo    <= dividend;
                dvs    <= divisor;
                step   <= 3'd0;
            end else if (busy) begin
                if (abort) begin
                    busy <= 1'b0;
                    step <= 3'd0;
                end else begin
                    rem  <= rem_next;
                    quo  <= quo_next;
                    step <= step + 3'd1;
                    if (last_step) begin
                        busy      <= 1'b0;
                        done      <= 1'b1;
                        quotient  <= quo_next;
                        remainder <= rem_next;
                        div0      <= (dvs == 8'd0);
                    end
                end
            end
        end
    end
endmodule
