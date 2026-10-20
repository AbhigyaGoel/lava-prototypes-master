`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0;
    reg [7:0] a = 0, b = 0;
    wire busy, done;
    wire [15:0] product;
    integer errors = 0, n;

    mult_seq dut (.clk(clk), .rst_n(rst_n), .start(start), .a(a), .b(b),
                  .busy(busy), .done(done), .product(product));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task run(input signed [7:0] x, input signed [7:0] y);
        reg signed [15:0] exp;
        begin
            exp = x * y;
            @(negedge clk); start = 1; a = x; b = y;
            @(negedge clk); start = 0;
            if (busy !== 1'b1) begin $display("FAIL: busy not set after start"); errors = errors + 1; end
            n = 0;
            while (done !== 1'b1 && n < 20) begin @(negedge clk); n = n + 1; end
            if (done !== 1'b1 || n != 8) begin
                $display("FAIL: done after %0d cycles (expected 8)", n); errors = errors + 1;
            end
            if (busy !== 1'b0) begin $display("FAIL: busy still high at done"); errors = errors + 1; end
            if (product !== exp) begin
                $display("FAIL: %0d * %0d = %0d, expected %0d", x, y, $signed(product), exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        if (busy !== 1'b0 || done !== 1'b0 || product !== 16'd0) begin
            $display("FAIL: bad state after reset"); errors = errors + 1;
        end
        run(3, 5);
        run(12, 11);
        run(-6, 4);
        run(7, -2);
        run(-9, -9);
        run(0, 25);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
