`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, wr_en = 0, rd_en = 0;
    reg [7:0] din = 0;
    wire [7:0] dout;
    wire full, empty;
    wire [3:0] count;
    integer errors = 0, i;

    sync_fifo dut (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din), .rd_en(rd_en),
                   .dout(dout), .full(full), .empty(empty), .count(count));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_flags(input [3:0] c, input f, input e);
        if (count !== c || full !== f || empty !== e) begin
            $display("FAIL: t=%0t count=%0d full=%b empty=%b expected count=%0d full=%b empty=%b",
                     $time, count, full, empty, c, f, e);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        expect_flags(0, 0, 1);
        // fill completely
        for (i = 0; i < 8; i = i + 1) begin
            wr_en = 1; din = 8'h10 + i;
            @(negedge clk);
        end
        wr_en = 0;
        expect_flags(8, 1, 0);
        // drain completely, checking order
        for (i = 0; i < 8; i = i + 1) begin
            rd_en = 1;
            @(negedge clk);
            if (dout !== 8'h10 + i) begin
                $display("FAIL: read %0d dout=%h expected=%h", i, dout, 8'h10 + i);
                errors = errors + 1;
            end
        end
        rd_en = 0;
        expect_flags(0, 0, 1);
        // a few more with pointer wrap
        for (i = 0; i < 3; i = i + 1) begin
            wr_en = 1; din = 8'hA0 + i;
            @(negedge clk);
        end
        wr_en = 0;
        expect_flags(3, 0, 0);
        for (i = 0; i < 3; i = i + 1) begin
            rd_en = 1;
            @(negedge clk);
            if (dout !== 8'hA0 + i) begin
                $display("FAIL: read dout=%h expected=%h", dout, 8'hA0 + i);
                errors = errors + 1;
            end
        end
        rd_en = 0;
        expect_flags(0, 0, 1);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
