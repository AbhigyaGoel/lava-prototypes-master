`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, en = 0, load = 0, dir = 0, sin = 0;
    reg [7:0] d = 0;
    wire [7:0] q;
    wire sout;
    integer errors = 0, i;
    reg [7:0] q_ref;

    shift_reg dut (.clk(clk), .rst_n(rst_n), .en(en), .load(load), .dir(dir), .sin(sin),
                   .d(d), .q(q), .sout(sout));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (q !== q_ref || sout !== (dir ? q_ref[0] : q_ref[7])) begin
            $display("FAIL: t=%0t q=%h sout=%b expected q=%h", $time, q, sout, q_ref);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        // parallel load
        en = 1; load = 1; d = 8'hA5;
        @(posedge clk); #1; q_ref = 8'hA5; check;
        @(negedge clk) load = 0;
        // shift left with serial input pattern
        for (i = 0; i < 8; i = i + 1) begin
            dir = 0; sin = i[0];
            @(posedge clk); #1; q_ref = {q_ref[6:0], sin}; check;
            @(negedge clk);
        end
        // shift right (zero fill)
        load = 1; d = 8'hF0;
        @(posedge clk); #1; q_ref = 8'hF0; check;
        @(negedge clk) load = 0;
        for (i = 0; i < 4; i = i + 1) begin
            dir = 1; sin = 0;
            @(posedge clk); #1; q_ref = {sin, q_ref[7:1]}; check;
            @(negedge clk);
        end
        // hold
        en = 0;
        @(posedge clk); #1; check;
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
