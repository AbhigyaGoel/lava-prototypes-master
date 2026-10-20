`timescale 1ns/1ps
module tb;
    reg        clk = 0, rst_n = 1;
    reg  [7:0] rate = 8'd4;
    reg        req = 0, clr_stats = 0;
    wire       grant, empty, full, refill;
    wire [2:0] tokens;
    wire [7:0] deny_cnt;
    integer errors = 0, i, mode, dens;

    localparam integer CAP = 4;

    // reference model
    integer    m_tok, m_deny;
    reg  [7:0] m_timer;
    reg        e_refill, e_grant;

    token_bucket dut (.clk(clk), .rst_n(rst_n), .rate(rate), .req(req), .clr_stats(clr_stats),
                      .grant(grant), .tokens(tokens), .empty(empty), .full(full), .refill(refill),
                      .deny_cnt(deny_cnt));
    always #5 clk = ~clk;
    initial begin #50000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_tok = CAP; m_deny = 0; m_timer = 0; end
    endtask

    task check;
        begin
            e_refill = (rate != 0) && (m_timer >= rate - 8'd1);
            e_grant  = req && (m_tok != 0);
            if (tokens !== m_tok[2:0] || grant !== e_grant || refill !== e_refill ||
                empty !== (m_tok == 0) || full !== (m_tok == CAP) || deny_cnt !== m_deny[7:0]) begin
                if (errors < 25)
                    $display("FAIL: t=%0t rate=%0d req=%b timer_ref=%0d | tokens=%0d/%0d grant=%b/%b refill=%b/%b empty=%b full=%b deny=%0d/%0d (got/exp)",
                             $time, rate, req, m_timer, tokens, m_tok, grant, e_grant, refill, e_refill,
                             empty, full, deny_cnt, m_deny);
                errors = errors + 1;
            end
        end
    endtask

    // drive at negedge, check, update the model at posedge
    task cycle(input [7:0] r, input q, input c);
        begin
            @(negedge clk);
            rate = r; req = q; clr_stats = c;
            #1 check;
            @(posedge clk);
            m_tok = m_tok - e_grant + e_refill;
            if (m_tok > CAP) m_tok = CAP;
            if (rate == 0 || e_refill) m_timer = 0; else m_timer = m_timer + 1;
            if (c) m_deny = 0;
            else if (req && !e_grant && m_deny != 255) m_deny = m_deny + 1;
        end
    endtask

    function [7:0] rand_rate(input integer r);
        begin
            case (r % 12)
                0:       rand_rate = 8'd0;
                1, 2:    rand_rate = 8'd1;
                3, 4:    rand_rate = 8'd2;
                5, 6:    rand_rate = 8'd3;
                7:       rand_rate = 8'd5;
                8:       rand_rate = 8'd8;
                9:       rand_rate = 8'd13;
                10:      rand_rate = 8'd255;
                default: rand_rate = 1 + ({$random} % 40);
            endcase
        end
    endfunction

    initial begin
        model_reset;
        #1 rst_n = 0;
        #2 check;
        @(negedge clk); rst_n = 1;

        // directed: refill every cycle while full and requesting every cycle
        for (i = 0; i < 10; i = i + 1) cycle(8'd1, 1, 0);
        // directed: refill and grant together at capacity with a slower rate
        for (i = 0; i < 20; i = i + 1) cycle(8'd3, (i % 3) == 2, 0);
        // directed: drain, then shorten the period below the elapsed count
        for (i = 0; i < 6; i = i + 1) cycle(8'd40, 1, 0);
        for (i = 0; i < 10; i = i + 1) cycle(8'd40, 0, 0);
        cycle(8'd4, 0, 0);
        cycle(8'd2, 0, 0);
        for (i = 0; i < 10; i = i + 1) cycle(8'd200, 0, 0);
        cycle(8'd1, 0, 0);
        // directed: lengthen the period mid-count
        for (i = 0; i < 6; i = i + 1) cycle(8'd5, 1, 0);
        for (i = 0; i < 12; i = i + 1) cycle(8'd9, 0, 0);
        // directed: rate 0 disables refill (long enough for any timer wrap), then re-enable
        for (i = 0; i < 6; i = i + 1) cycle(8'd7, 1, 0);
        for (i = 0; i < 700; i = i + 1) cycle(8'd0, (i % 50) == 0, 0);
        for (i = 0; i < 30; i = i + 1) cycle(8'd6, 0, 0);
        // directed: saturate the deny counter, clear while denying
        for (i = 0; i < 300; i = i + 1) cycle(8'd0, 1, 0);
        cycle(8'd0, 1, 1);
        cycle(8'd0, 1, 0);
        cycle(8'd0, 0, 1);

        // random: rate changes at random points (up and down), varied request density
        cycle(8'd3, 0, 0);
        for (mode = 0; mode < 6; mode = mode + 1) begin
            dens = (mode % 3 == 0) ? 2 : (mode % 3 == 1) ? 8 : 14;   // req probability /16
            for (i = 0; i < 2500; i = i + 1)
                cycle((({$random} % 24) == 0) ? rand_rate($random) : rate,
                      ({$random} % 16) < dens, ({$random} % 64) == 0);
        end

        // async reset mid-operation
        for (i = 0; i < 7; i = i + 1) cycle(8'd9, 1, 0);
        @(negedge clk); #2 rst_n = 0; #1 model_reset; #1 check;
        #2 rst_n = 1;
        for (i = 0; i < 2000; i = i + 1)
            cycle((({$random} % 16) == 0) ? rand_rate($random) : rate, $random, 0);

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
