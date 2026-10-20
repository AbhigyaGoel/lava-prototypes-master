// ----------------------------------------------------------------------------
// token_bucket
//
// Token-bucket rate limiter. The bucket holds up to CAP tokens and starts full
// after reset. A refill timer adds one token every `rate` cycles (rate = 0
// disables refill). A request is granted when the bucket is not empty and each
// grant consumes one token. deny_cnt counts rejected requests (saturating).
//
// All outputs except `tokens` and `deny_cnt` are combinational.
// ----------------------------------------------------------------------------
module token_bucket #(
    parameter integer CAP = 4,          // bucket capacity (tokens), 1 <= CAP < 2**TW
    parameter integer TW  = 3,          // token counter width
    parameter integer RW  = 8           // refill period width
) (
    input  wire          clk,
    input  wire          rst_n,
    input  wire [RW-1:0] rate,          // refill period in cycles, 0 = refill disabled
    input  wire          req,           // request (one token per granted request)
    input  wire          clr_stats,     // synchronous clear of deny_cnt
    output wire          grant,
    output reg  [TW-1:0] tokens,
    output wire          empty,
    output wire          full,
    output wire          refill,
    output reg  [7:0]    deny_cnt
);
    localparam [TW-1:0] CAP_V = CAP;

    reg [RW-1:0] timer;
    reg [TW-1:0] tokens_nx;

    // ------------------------------------------------------------------
    // Refill timer: one token every `rate` cycles
    // ------------------------------------------------------------------
    assign refill = (rate != {RW{1'b0}}) && (timer >= rate - 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= {RW{1'b0}};
        else if (rate == {RW{1'b0}})
            timer <= {RW{1'b0}};
        else if (refill)
            timer <= {RW{1'b0}};
        else
            timer <= timer + 1'b1;
    end

    // ------------------------------------------------------------------
    // Grant / token accounting
    // ------------------------------------------------------------------
    assign empty = (tokens == {TW{1'b0}});
    assign full  = (tokens == CAP_V);
    assign grant = req && !empty;

    always @(*) begin
        if (!grant && refill && tokens < CAP_V)
            tokens_nx = tokens + 1'b1;
        else if (grant && !refill)
            tokens_nx = tokens - 1'b1;
        else
            tokens_nx = tokens;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tokens <= CAP_V;
        else
            tokens <= tokens_nx;
    end

    // ------------------------------------------------------------------
    // Statistics: saturating count of denied requests
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            deny_cnt <= 8'd0;
        else if (clr_stats)
            deny_cnt <= 8'd0;
        else if (req && !grant && deny_cnt != 8'hFF)
            deny_cnt <= deny_cnt + 8'd1;
    end
endmodule
