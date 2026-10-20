`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0, abort = 0;
    reg [7:0] dividend = 0, divisor = 0;
    wire busy, done, div0;
    wire [7:0] quotient, remainder;
    integer errors = 0, cycles;

    div_seq dut (.clk(clk), .rst_n(rst_n), .start(start), .abort(abort), .dividend(dividend),
                 .divisor(divisor), .busy(busy), .done(done), .quotient(quotient),
                 .remainder(remainder), .div0(div0));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task divide(input [7:0] a, input [7:0] b, input [7:0] eq, input [7:0] er, input ez);
        begin
            @(negedge clk); dividend = a; divisor = b; start = 1;
            @(negedge clk); start = 0;
            cycles = 1;
            while (done !== 1'b1 && cycles < 50) begin @(negedge clk); cycles = cycles + 1; end
            if (cycles != 9) begin $display("FAIL: %0d/%0d took %0d cycles, expected 9", a, b, cycles); errors = errors + 1; end
            if (quotient !== eq || remainder !== er || div0 !== ez || busy !== 1'b0) begin
                $display("FAIL: %0d/%0d -> q=%0d r=%0d div0=%b busy=%b, expected q=%0d r=%0d div0=%b",
                         a, b, quotient, remainder, div0, busy, eq, er, ez);
                errors = errors + 1;
            end
            @(negedge clk);
            if (done !== 1'b0) begin $display("FAIL: done longer than one cycle"); errors = errors + 1; end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        divide(8'd100, 8'd7, 8'd14, 8'd2, 1'b0);
        divide(8'd255, 8'd16, 8'd15, 8'd15, 1'b0);
        divide(8'd5, 8'd9, 8'd0, 8'd5, 1'b0);
        divide(8'd42, 8'd0, 8'hFF, 8'd42, 1'b1);
        divide(8'd81, 8'd9, 8'd9, 8'd0, 1'b0);
        divide(8'd200, 8'd1, 8'd200, 8'd0, 1'b0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
