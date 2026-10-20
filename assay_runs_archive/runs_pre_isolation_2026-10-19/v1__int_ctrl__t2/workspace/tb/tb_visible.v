`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] src = 0;
    reg we = 0, ack = 0;
    reg [1:0] addr = 0;
    reg [7:0] wdata = 0;
    reg [2:0] ack_id = 0;
    wire [7:0] pending;
    wire irq;
    wire [2:0] irq_id;
    integer errors = 0;

    int_ctrl dut (.clk(clk), .rst_n(rst_n), .src(src), .we(we), .addr(addr), .wdata(wdata),
                  .ack(ack), .ack_id(ack_id), .pending(pending), .irq(irq), .irq_id(irq_id));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check(input [7:0] p, input i, input [2:0] id);
        if (pending !== p || irq !== i || (i && irq_id !== id)) begin
            $display("FAIL: t=%0t pending=%h irq=%b irq_id=%0d expected pending=%h irq=%b irq_id=%0d",
                     $time, pending, irq, irq_id, p, i, id);
            errors = errors + 1;
        end
    endtask

    task write_reg(input [1:0] a, input [7:0] d);
        begin
            @(negedge clk); we = 1; addr = a; wdata = d;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        #1 check(8'h00, 0, 0);
        write_reg(2'd1, 8'h0F);          // sources 0-3 edge, 4-7 level
        write_reg(2'd0, 8'hFF);          // all enabled
        #1 check(8'h00, 0, 0);
        // edge source 2: pulse, latches, then acknowledge
        @(negedge clk); src = 8'h04;
        @(negedge clk); src = 8'h00; #1 check(8'h04, 1, 2);
        @(negedge clk); #1 check(8'h04, 1, 2);
        ack = 1; ack_id = 3'd2;
        @(negedge clk); ack = 0; #1 check(8'h00, 0, 0);
        // level source 5 follows its line
        src = 8'h20; #1 check(8'h20, 1, 5);
        @(negedge clk); #1 check(8'h20, 1, 5);
        src = 8'h00; #1 check(8'h00, 0, 0);
        // masked level source: pending but no irq
        write_reg(2'd0, 8'hDF);
        src = 8'h20; #1 check(8'h20, 0, 0);
        @(negedge clk); src = 8'h00; #1 check(8'h00, 0, 0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
