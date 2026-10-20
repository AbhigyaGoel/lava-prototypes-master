`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire found;
    integer errors = 0, i;
    // stream: 0 1011 0 11 1011 1 1011 011 000
    reg [0:22] stream  = 23'b0_1011_0_11_1011_1_1011_011_000;
    reg [0:22] exp_bit = 23'b0_0001_0_01_0001_0_0001_001_000;

    seq_detector dut (.clk(clk), .rst_n(rst_n), .din(din), .found(found));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        if (found !== 1'b0) begin $display("FAIL: found not 0 after reset"); errors = errors + 1; end
        for (i = 0; i < 23; i = i + 1) begin
            din = stream[i];
            @(posedge clk); #1;
            if (found !== exp_bit[i]) begin
                $display("FAIL: bit %0d din=%b found=%b expected=%b", i, stream[i], found, exp_bit[i]);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
