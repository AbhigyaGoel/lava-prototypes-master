`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire rise, fall, any;
    integer errors = 0, i;
    reg s1, s2, pv;

    edge_detector dut (.clk(clk), .rst_n(rst_n), .din(din), .rise(rise), .fall(fall), .any(any));
    always #5 clk = ~clk;
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (rise !== (s2 & ~pv) || fall !== (~s2 & pv) || any !== (s2 ^ pv)) begin
            $display("FAIL: t=%0t rise=%b fall=%b any=%b expected %b %b %b",
                     $time, rise, fall, any, s2 & ~pv, ~s2 & pv, s2 ^ pv);
            errors = errors + 1;
        end
    endtask

    // din changes at negedge; model updates at posedge, check just after
    task step(input v);
        begin
            din = v;
            #1 check;
            @(posedge clk);
            pv = s2; s2 = s1; s1 = din;
            #1 check;
            @(negedge clk);
        end
    endtask

    initial begin
        s1 = 0; s2 = 0; pv = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        @(negedge clk);
        // single-cycle pulses, back-to-back toggles, long holds
        step(1); step(0); step(0); step(0);
        step(1); step(1); step(1); step(1);
        step(0); step(1); step(0); step(1); step(0); step(0); step(0);
        for (i = 0; i < 3000; i = i + 1) step($random);
        // din high across reset release
        step(1); step(1);
        #2 rst_n = 0; #1 s1 = 0; s2 = 0; pv = 0; check;
        #3 rst_n = 1;
        @(negedge clk);
        for (i = 0; i < 8; i = i + 1) step(1);
        for (i = 0; i < 500; i = i + 1) step($random);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
