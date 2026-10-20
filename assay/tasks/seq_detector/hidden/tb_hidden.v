`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire found;
    integer errors = 0, i;
    reg [3:0] hist;     // last 4 bits sampled since reset, newest in bit 0
    integer nbits;      // bits sampled since reset (saturating)
    reg exp_found;
    reg [0:13] directed = 14'b10101011_101011;

    seq_detector dut (.clk(clk), .rst_n(rst_n), .din(din), .found(found));
    always #5 clk = ~clk;
    initial begin #1000000 $display("ERROR: watchdog timeout"); $finish; end

    task step(input bit_in);
        begin
            din = bit_in;
            @(posedge clk); #1;
            hist = {hist[2:0], bit_in};
            if (nbits < 4) nbits = nbits + 1;
            exp_found = (nbits >= 4) && (hist == 4'b1011);
            if (found !== exp_found) begin
                $display("FAIL: t=%0t din=%b hist=%b found=%b expected=%b", $time, bit_in, hist, found, exp_found);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        hist = 0; nbits = 0;
        #1 rst_n = 0;
        #2 if (found !== 1'b0) begin $display("FAIL: found not 0 in reset"); errors = errors + 1; end
        #9 rst_n = 1;
        for (i = 0; i < 14; i = i + 1) step(directed[i]);
        for (i = 0; i < 2000; i = i + 1) step($random);
        // async reset in the middle of a partial match: "101" then reset then "1"
        step(1); step(0); step(1);
        #2 rst_n = 0; #1 hist = 0; nbits = 0;
        if (found !== 1'b0) begin $display("FAIL: found not 0 in reset"); errors = errors + 1; end
        #3 rst_n = 1;
        step(1); step(0); step(1); step(1);
        for (i = 0; i < 1000; i = i + 1) step(($random % 4) != 0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
