`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, clear = 0, valid = 0;
    reg [7:0] data = 0;
    wire [7:0] crc;
    integer errors = 0, i;

    crc8 dut (.clk(clk), .rst_n(rst_n), .clear(clear), .valid(valid), .data(data), .crc(crc));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_crc(input [7:0] exp);
        if (crc !== exp) begin
            $display("FAIL: t=%0t crc=%h expected=%h", $time, crc, exp);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        expect_crc(8'h00);
        // "123456789" -> 0xF4
        for (i = 0; i < 9; i = i + 1) begin
            @(negedge clk); valid = 1; data = 8'h31 + i;
        end
        @(negedge clk); valid = 0;
        expect_crc(8'hF4);
        // clear
        clear = 1; @(negedge clk); clear = 0;
        expect_crc(8'h00);
        // single byte 0x01 -> 0x07
        valid = 1; data = 8'h01; @(negedge clk); valid = 0;
        expect_crc(8'h07);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
