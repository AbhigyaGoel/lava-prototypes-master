`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] div = 8'd4;
    wire clk_out, tick;
    integer errors = 0, i;
    reg [7:0] cnt_ref;

    clock_divider dut (.clk(clk), .rst_n(rst_n), .div(div), .clk_out(clk_out), .tick(tick));
    always #5 clk = ~clk;
    initial begin #5000000 $display("ERROR: watchdog timeout"); $finish; end

    function [7:0] neff(input [7:0] d);
        neff = (d < 8'd2) ? 8'd2 : d;
    endfunction

    task check;
        begin
            if (tick !== (cnt_ref >= neff(div) - 8'd1) ||
                clk_out !== (cnt_ref < (neff(div) >> 1))) begin
                $display("FAIL: t=%0t div=%0d cnt=%0d tick=%b clk_out=%b expected tick=%b clk_out=%b",
                         $time, div, cnt_ref, tick, clk_out,
                         cnt_ref >= neff(div) - 8'd1, cnt_ref < (neff(div) >> 1));
                errors = errors + 1;
            end
        end
    endtask

    task step;
        begin
            #1 check;
            @(posedge clk);
            if (cnt_ref >= neff(div) - 8'd1) cnt_ref = 8'd0;
            else cnt_ref = cnt_ref + 8'd1;
            #1 check;
            @(negedge clk);
        end
    endtask

    task run_const(input [7:0] d, input integer n);
        integer k;
        begin
            div = d;
            for (k = 0; k < n; k = k + 1) step;
        end
    endtask

    initial begin
        cnt_ref = 0;
        #1 rst_n = 0;
        #2 check;
        @(negedge clk) rst_n = 1;
        // small and degenerate divisors
        run_const(8'd2, 12);
        run_const(8'd1, 12);
        run_const(8'd0, 12);
        run_const(8'd3, 12);
        run_const(8'd4, 16);
        run_const(8'd7, 21);
        // reduce divisor while the counter is beyond the new terminal count
        run_const(8'd20, 15);
        run_const(8'd6, 10);
        run_const(8'd200, 150);
        run_const(8'd3, 9);
        run_const(8'd9, 7);
        run_const(8'd1, 6);
        run_const(8'd255, 300);
        // random divisor changes at random times
        for (i = 0; i < 3000; i = i + 1) begin
            if (($random & 15) == 0) div = (($random & 3) == 0) ? $random : ($random & 15);
            step;
        end
        // async reset mid-period
        run_const(8'd10, 7);
        #2 rst_n = 0; #1 cnt_ref = 0; check;
        #3 rst_n = 1;
        @(negedge clk);
        run_const(8'd10, 25);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
