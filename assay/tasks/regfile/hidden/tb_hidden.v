`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, we = 0;
    reg [2:0] waddr = 0, raddr1 = 0, raddr2 = 0;
    reg [7:0] wdata = 0;
    wire [7:0] rdata1, rdata2;
    integer errors = 0, i, k;
    reg [7:0] model [0:7];

    regfile dut (.clk(clk), .rst_n(rst_n), .we(we), .waddr(waddr), .wdata(wdata),
                 .raddr1(raddr1), .rdata1(rdata1), .raddr2(raddr2), .rdata2(rdata2));
    always #5 clk = ~clk;
    initial begin #1000000 $display("ERROR: watchdog timeout"); $finish; end

    function [7:0] exp_read(input [2:0] ra);
        if (ra == 0) exp_read = 8'd0;
        else if (we && waddr == ra) exp_read = wdata;
        else exp_read = model[ra];
    endfunction

    task check_reads;
        begin
            #1;
            if (rdata1 !== exp_read(raddr1)) begin
                $display("FAIL: t=%0t we=%b waddr=%0d wdata=%h rdata1[%0d]=%h expected %h",
                         $time, we, waddr, wdata, raddr1, rdata1, exp_read(raddr1));
                errors = errors + 1;
            end
            if (rdata2 !== exp_read(raddr2)) begin
                $display("FAIL: t=%0t we=%b waddr=%0d wdata=%h rdata2[%0d]=%h expected %h",
                         $time, we, waddr, wdata, raddr2, rdata2, exp_read(raddr2));
                errors = errors + 1;
            end
        end
    endtask

    // drive inputs at negedge, check combinational reads, update the model at posedge
    task cycle(input w, input [2:0] wa, input [7:0] wd, input [2:0] r1, input [2:0] r2);
        begin
            @(negedge clk);
            we = w; waddr = wa; wdata = wd; raddr1 = r1; raddr2 = r2;
            check_reads;
            @(posedge clk);
            if (we && waddr != 0) model[waddr] = wdata;
        end
    endtask

    initial begin
        for (k = 0; k < 8; k = k + 1) model[k] = 0;
        #1 rst_n = 0;
        #11 rst_n = 1;
        for (k = 1; k < 8; k = k + 1) cycle(1, k, 8'h30 + k, 0, 0);
        // write to r0 while reading r0 on both ports
        cycle(1, 0, 8'h5A, 0, 0);
        // we=0 with waddr matching the read address and stale wdata differing
        cycle(0, 3, 8'hEE, 3, 3);
        cycle(0, 6, 8'h11, 6, 2);
        // bypass on port 2
        cycle(1, 5, 8'h77, 1, 5);
        cycle(1, 5, 8'h78, 5, 5);
        cycle(0, 5, 8'h00, 5, 5);
        for (i = 0; i < 3000; i = i + 1)
            cycle($random, $random, $random, $random, $random);
        // async reset mid-operation
        @(negedge clk); #2 rst_n = 0; #1;
        for (k = 0; k < 8; k = k + 1) model[k] = 0;
        we = 0;
        for (k = 0; k < 8; k = k + 1) begin
            raddr1 = k; raddr2 = 7 - k; check_reads;
        end
        #1 rst_n = 1;
        for (i = 0; i < 1000; i = i + 1)
            cycle($random, $random, $random, $random, $random);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
