`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg load = 0, en = 0, auto_reload = 0, irq_clr = 0;
    reg [15:0] load_val = 0;
    wire [15:0] count;
    wire irq;
    integer errors = 0, i;

    timer_irq dut (.clk(clk), .rst_n(rst_n), .load(load), .load_val(load_val), .en(en),
                   .auto_reload(auto_reload), .irq_clr(irq_clr), .count(count), .irq(irq));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check(input [15:0] ec, input ei);
        if (count !== ec || irq !== ei) begin
            $display("FAIL: t=%0t count=%0d irq=%b expected count=%0d irq=%b", $time, count, irq, ec, ei);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        check(0, 0);
        // one-shot: load 5, count down to 0, irq raised
        @(negedge clk); load = 1; load_val = 16'd5;
        @(negedge clk); load = 0; check(5, 0);
        en = 1;
        for (i = 4; i >= 1; i = i - 1) begin
            @(negedge clk); check(i, 0);
        end
        @(negedge clk); check(0, 1);
        // stays at 0, irq sticky
        repeat (3) begin @(negedge clk); check(0, 1); end
        // clear irq
        irq_clr = 1;
        @(negedge clk); irq_clr = 0; check(0, 0);
        // enable low holds the count
        load = 1; load_val = 16'd300;
        @(negedge clk); load = 0; en = 0;
        repeat (4) begin @(negedge clk); check(300, 0); end
        en = 1;
        @(negedge clk); check(299, 0);
        // reload while running
        load = 1; load_val = 16'd2;
        @(negedge clk); load = 0; check(2, 0);
        @(negedge clk); check(1, 0);
        @(negedge clk); check(0, 1);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
