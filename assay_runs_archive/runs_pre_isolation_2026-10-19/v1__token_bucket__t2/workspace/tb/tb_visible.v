`timescale 1ns/1ps
module tb;
    reg        clk = 0, rst_n = 1;
    reg  [7:0] rate = 8'd4;
    reg        req = 0, clr_stats = 0;
    wire       grant, empty, full, refill;
    wire [2:0] tokens;
    wire [7:0] deny_cnt;
    integer errors = 0, i;

    token_bucket dut (.clk(clk), .rst_n(rst_n), .rate(rate), .req(req), .clr_stats(clr_stats),
                      .grant(grant), .tokens(tokens), .empty(empty), .full(full), .refill(refill),
                      .deny_cnt(deny_cnt));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    // expected grant/tokens for 12 cycles of continuous requests at rate 4, starting full
    reg [11:0] exp_grant = 12'b0001_0001_1111;   // bit i = cycle i
    integer    exp_tok [0:11];

    initial begin
        exp_tok[0] = 4; exp_tok[1] = 3; exp_tok[2] = 2; exp_tok[3] = 1; exp_tok[4] = 1;
        exp_tok[5] = 0; exp_tok[6] = 0; exp_tok[7] = 0; exp_tok[8] = 1; exp_tok[9] = 0;
        exp_tok[10] = 0; exp_tok[11] = 0;
        #1 rst_n = 0;
        #2;
        if (tokens !== 3'd4 || full !== 1'b1 || empty !== 1'b0 || deny_cnt !== 8'd0) begin
            $display("FAIL: reset state tokens=%0d full=%b empty=%b", tokens, full, empty);
            errors = errors + 1;
        end
        @(negedge clk); rst_n = 1;
        // drain with continuous requests
        for (i = 0; i < 12; i = i + 1) begin
            req = 1; #1;
            if (tokens !== exp_tok[i] || grant !== exp_grant[i]) begin
                $display("FAIL: cycle %0d tokens=%0d grant=%b expected tokens=%0d grant=%b",
                         i, tokens, grant, exp_tok[i], exp_grant[i]);
                errors = errors + 1;
            end
            @(negedge clk);
        end
        req = 0;
        if (deny_cnt !== 8'd6) begin
            $display("FAIL: deny_cnt=%0d expected 6", deny_cnt); errors = errors + 1;
        end
        // idle: bucket refills to capacity and stays there
        repeat (30) @(negedge clk);
        if (tokens !== 3'd4 || full !== 1'b1) begin
            $display("FAIL: bucket not refilled, tokens=%0d", tokens); errors = errors + 1;
        end
        // clear statistics
        clr_stats = 1; @(negedge clk); clr_stats = 0;
        if (deny_cnt !== 8'd0) begin
            $display("FAIL: deny_cnt not cleared (%0d)", deny_cnt); errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
