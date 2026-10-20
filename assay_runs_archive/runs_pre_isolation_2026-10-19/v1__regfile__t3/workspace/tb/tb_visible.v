`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, we = 0;
    reg [2:0] waddr = 0, raddr1 = 0, raddr2 = 0;
    reg [7:0] wdata = 0;
    wire [7:0] rdata1, rdata2;
    integer errors = 0, i;

    regfile dut (.clk(clk), .rst_n(rst_n), .we(we), .waddr(waddr), .wdata(wdata),
                 .raddr1(raddr1), .rdata1(rdata1), .raddr2(raddr2), .rdata2(rdata2));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task write(input [2:0] addr, input [7:0] data);
        begin
            @(negedge clk); we = 1; waddr = addr; wdata = data;
            @(negedge clk); we = 0;
        end
    endtask

    task read_check(input [2:0] a1, input [7:0] e1, input [2:0] a2, input [7:0] e2);
        begin
            raddr1 = a1; raddr2 = a2; #1;
            if (rdata1 !== e1) begin
                $display("FAIL: rdata1[%0d]=%h expected %h", a1, rdata1, e1); errors = errors + 1;
            end
            if (rdata2 !== e2) begin
                $display("FAIL: rdata2[%0d]=%h expected %h", a2, rdata2, e2); errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        read_check(3'd3, 8'h00, 3'd5, 8'h00);
        for (i = 1; i < 8; i = i + 1) write(i, 8'h10 * i + i);
        for (i = 1; i < 8; i = i + 1) read_check(i, 8'h10 * i + i, 8 - i, 8'h10 * (8 - i) + (8 - i));
        // register 0 stays zero
        write(3'd0, 8'hAA);
        write(3'd1, 8'h5B);
        read_check(3'd0, 8'h00, 3'd1, 8'h5B);
        read_check(3'd1, 8'h5B, 3'd0, 8'h00);
        // same-cycle bypass on port 1
        @(negedge clk); we = 1; waddr = 3'd4; wdata = 8'hC4;
        read_check(3'd4, 8'hC4, 3'd2, 8'h22);
        @(negedge clk); we = 0;
        read_check(3'd4, 8'hC4, 3'd4, 8'hC4);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
