`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0, abort = 0;
    reg [7:0] dividend = 0, divisor = 0;
    wire busy, done, div0;
    wire [7:0] quotient, remainder;
    integer errors = 0, i, j, n, ops = 0;

    // reference model
    reg       m_busy, m_done, m_div0;
    reg [7:0] m_q, m_r, m_a, m_b;
    integer   m_left;

    div_seq dut (.clk(clk), .rst_n(rst_n), .start(start), .abort(abort), .dividend(dividend),
                 .divisor(divisor), .busy(busy), .done(done), .quotient(quotient),
                 .remainder(remainder), .div0(div0));
    always #5 clk = ~clk;
    initial begin #50000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin
            m_busy = 0; m_done = 0; m_div0 = 0; m_q = 0; m_r = 0; m_a = 0; m_b = 0; m_left = 0;
        end
    endtask

    task model_step;
        begin
            m_done = 0;
            if (!m_busy) begin
                if (start) begin
                    m_busy = 1; m_a = dividend; m_b = divisor; m_left = 8;
                end
            end else if (abort) begin
                m_busy = 0;
            end else begin
                m_left = m_left - 1;
                if (m_left == 0) begin
                    m_busy = 0; m_done = 1; ops = ops + 1;
                    if (m_b == 0) begin m_q = 8'hFF; m_r = m_a; m_div0 = 1; end
                    else begin m_q = m_a / m_b; m_r = m_a % m_b; m_div0 = 0; end
                end
            end
        end
    endtask

    task check;
        if (busy !== m_busy || done !== m_done || quotient !== m_q || remainder !== m_r || div0 !== m_div0) begin
            if (errors < 20)
                $display("FAIL: t=%0t op %0d/%0d dut busy=%b done=%b q=%0d r=%0d div0=%b | exp %b %b %0d %0d %b",
                         $time, m_a, m_b, busy, done, quotient, remainder, div0,
                         m_busy, m_done, m_q, m_r, m_div0);
            errors = errors + 1;
        end
    endtask

    task cycle(input s, input ab, input [7:0] a, input [7:0] b);
        begin
            @(negedge clk);
            check;
            start = s; abort = ab; dividend = a; divisor = b;
            @(posedge clk);
            model_step;
        end
    endtask

    // one clean division: operands change randomly while busy, start pulses are ignored
    task divide(input [7:0] a, input [7:0] b);
        begin
            cycle(1, 0, a, b);
            n = 0;
            while (m_busy && n < 20) begin
                cycle($random, 0, $random, $random);
                n = n + 1;
            end
        end
    endtask

    initial begin
        model_reset;
        #1 rst_n = 0;
        #11 rst_n = 1;
        // directed: all divisors against extreme and random dividends
        for (j = 0; j < 256; j = j + 1) begin
            divide(8'd255, j); divide(8'd254, j); divide(8'd0, j); divide(8'd128, j);
            divide(j, j); divide(j - 1, j); divide($random, j); divide($random, j);
        end
        // directed: large divisors, partial remainder >= 128
        for (i = 0; i < 2000; i = i + 1) divide($random | 8'h80, $random | 8'h80);
        // directed: start held high -> back-to-back divisions (restart in the done cycle)
        for (i = 0; i < 100; i = i + 1) cycle(1, 0, $random, $random);
        // directed: abort on every possible iteration, including the last one
        for (j = 0; j < 9; j = j + 1) begin
            cycle(1, 0, 8'd200, 8'd7);
            for (i = 0; i < j; i = i + 1) cycle(0, 0, $random, $random);
            cycle($random, 1, $random, $random);
            cycle(0, 0, 0, 0); cycle(0, 0, 0, 0);
        end
        // directed: start and abort together while idle -> start wins
        cycle(1, 1, 8'd99, 8'd10);
        for (i = 0; i < 10; i = i + 1) cycle(0, 0, $random, $random);
        // long random
        for (i = 0; i < 40000; i = i + 1)
            cycle(($random % 3) == 0, ($random % 40) == 0, $random,
                  (($random % 16) == 0) ? 8'd0 : $random);
        // asynchronous reset in the middle of a division
        cycle(1, 0, 8'd77, 8'd5); cycle(0, 0, 0, 0); cycle(0, 0, 0, 0);
        @(negedge clk); start = 0; #2 rst_n = 0; #1 model_reset; check; #1 rst_n = 1;
        @(posedge clk); model_step;
        for (i = 0; i < 2000; i = i + 1) cycle(($random % 3) == 0, 0, $random, $random);
        for (i = 0; i < 12; i = i + 1) cycle(0, 0, 0, 0);
        if (ops < 3000) begin $display("FAIL: only %0d divisions completed", ops); errors = errors + 1; end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
