// ----------------------------------------------------------------------------
// credit_tx
//
// Sender side of a credit-based flow-controlled link. Starts with N credits;
// each beat sent on the link consumes one credit and the receiver returns
// credits (credit_count, 1-3) through credit_return. Beats are only accepted
// from the source while at least one credit is held. Over-returns saturate the
// counter at N and raise credit_err.
//
// tx_valid / tx_data form a registered link interface (one beat per cycle).
// ----------------------------------------------------------------------------
module credit_tx #(
    parameter integer N  = 7,           // initial (and maximum) credit count
    parameter integer CW = 3            // credit counter width, N < 2**CW
) (
    input  wire          clk,
    input  wire          rst_n,
    // upstream (source) side
    input  wire          in_valid,
    input  wire [7:0]    in_data,
    output wire          in_ready,
    // link side
    output reg           tx_valid,
    output reg  [7:0]    tx_data,
    input  wire          credit_return,
    input  wire [1:0]    credit_count,
    // status
    output wire          can_send,
    output reg  [CW-1:0] credits,
    output reg           credit_err,
    output reg  [15:0]   beats_sent
);
    localparam [CW-1:0] N_V = N;

    // ------------------------------------------------------------------
    // Send qualification
    // ------------------------------------------------------------------
    assign can_send = (credits != {CW{1'b0}});
    assign in_ready = can_send;

    wire send = in_valid && can_send;

    // ------------------------------------------------------------------
    // Credit accounting
    // ------------------------------------------------------------------
    wire [1:0]      ret = credit_return ? credit_count : 2'd0;
    wire [CW+1:0]   s   = {2'b0, credits} - {{(CW+1){1'b0}}, send} + {{CW{1'b0}}, ret};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credits    <= N_V;
            credit_err <= 1'b0;
        end else begin
            if (s > N) begin
                credits    <= N_V;
                credit_err <= 1'b1;
            end else begin
                credits    <= s[CW-1:0];
                credit_err <= credit_err;
            end
        end
    end

    // ------------------------------------------------------------------
    // Link output register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_valid   <= 1'b0;
            tx_data    <= 8'h00;
            beats_sent <= 16'h0000;
        end else begin
            tx_valid <= send;
            if (send) begin
                tx_data    <= in_data;
                beats_sent <= beats_sent + 16'h0001;
            end
        end
    end
endmodule
