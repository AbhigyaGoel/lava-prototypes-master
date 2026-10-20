`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] div = 8'd4;
    wire clk_out, tick;
    integer errors = 0, i, highs, ticks;

    clock_divider dut (.clk(clk), .rst_n(rst_n), .div(div), .clk_out(clk_out), .tick(tick));
    always #5 clk = ~clk;
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    // reset, set divisor, then count highs/ticks over 10 full periods
    task run(input [7:0] d);
        begin
            rst_n = 1; #1 rst_n = 0;
            div = d;
            @(negedge clk) rst_n = 1;
            highs = 0; ticks = 0;
            for (i = 0; i < 10 * d; i = i + 1) begin
                #1;
                if (clk_out === 1'b1) highs = highs + 1;
                if (tick === 1'b1) ticks = ticks + 1;
                @(negedge clk);
            end
            if (highs !== 5 * (d / 2) * 2 || ticks !== 10) begin
                $display("FAIL: div=%0d highs=%0d ticks=%0d expected highs=%0d ticks=10",
                         d, highs, ticks, 5 * (d / 2) * 2);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1;
        run(8'd4);
        run(8'd6);
        run(8'd5);
        run(8'd2);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
