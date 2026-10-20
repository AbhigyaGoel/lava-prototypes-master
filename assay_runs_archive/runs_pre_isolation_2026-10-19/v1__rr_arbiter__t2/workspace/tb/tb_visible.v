`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [3:0] req = 0;
    wire [3:0] grant;
    integer errors = 0, i;

    rr_arbiter dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_grant(input [3:0] exp);
        if (grant !== exp) begin
            $display("FAIL: t=%0t req=%b grant=%b expected=%b", $time, req, grant, exp);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        req = 4'b0000; #1 expect_grant(4'b0000);
        // all requesting: grant rotates 0,1,2,3,0,...
        req = 4'b1111;
        for (i = 0; i < 8; i = i + 1) begin
            #1 expect_grant(4'b0001 << (i % 4));
            @(negedge clk);
        end
        // single requester always wins
        req = 4'b0100;
        for (i = 0; i < 3; i = i + 1) begin
            #1 expect_grant(4'b0100);
            @(negedge clk);
        end
        req = 4'b0000; #1 expect_grant(4'b0000);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
