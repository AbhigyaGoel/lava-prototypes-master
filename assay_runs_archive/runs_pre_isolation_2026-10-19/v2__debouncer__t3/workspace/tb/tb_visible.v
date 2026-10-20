`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire dout;
    integer errors = 0;

    debouncer #(.N(4)) dut (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_dout(input v);
        if (dout !== v) begin
            $display("FAIL: t=%0t dout=%b expected=%b", $time, dout, v);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        expect_dout(0);
        // short glitch must be filtered
        din = 1;
        repeat (2) @(negedge clk);
        din = 0;
        repeat (10) @(negedge clk);
        expect_dout(0);
        // stable high propagates
        din = 1;
        repeat (10) @(negedge clk);
        expect_dout(1);
        // stable low propagates
        din = 0;
        repeat (10) @(negedge clk);
        expect_dout(0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
