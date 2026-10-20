`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire dout4, dout7;
    integer errors = 0, i, run;
    reg  ref4, ref7;
    integer c4, c7;

    debouncer #(.N(4)) dut4 (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout4));
    debouncer #(.N(7)) dut7 (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout7));
    always #5 clk = ~clk;
    initial begin #2000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        begin
            if (dout4 !== ref4) begin
                $display("FAIL: t=%0t N=4 dout=%b expected=%b", $time, dout4, ref4);
                errors = errors + 1;
            end
            if (dout7 !== ref7) begin
                $display("FAIL: t=%0t N=7 dout=%b expected=%b", $time, dout7, ref7);
                errors = errors + 1;
            end
        end
    endtask

    // reference: count consecutive disagreeing samples
    task step(input v);
        begin
            din = v;
            @(posedge clk);
            if (din != ref4) begin
                c4 = c4 + 1;
                if (c4 == 4) begin ref4 = din; c4 = 0; end
            end else c4 = 0;
            if (din != ref7) begin
                c7 = c7 + 1;
                if (c7 == 7) begin ref7 = din; c7 = 0; end
            end else c7 = 0;
            #1 check;
            @(negedge clk);
        end
    endtask

    task hold(input v, input integer n);
        integer k;
        for (k = 0; k < n; k = k + 1) step(v);
    endtask

    initial begin
        ref4 = 0; ref7 = 0; c4 = 0; c7 = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        @(negedge clk);
        // exact threshold
        hold(1, 3); hold(0, 2);
        hold(1, 4); hold(1, 4);
        hold(0, 6); hold(0, 3);
        // repeated short glitches must never accumulate
        for (i = 0; i < 10; i = i + 1) begin hold(1, 3); hold(0, 1); end
        for (i = 0; i < 10; i = i + 1) begin hold(1, 6); hold(0, 1); end
        hold(1, 10);
        for (i = 0; i < 10; i = i + 1) begin hold(0, 2); hold(1, 1); end
        // randomized bursts of random length
        for (i = 0; i < 1500; i = i + 1) begin
            run = 1 + ($random & 7);
            hold($random, run);
        end
        // reset mid-count
        hold(1, 2);
        #2 rst_n = 0; #1 ref4 = 0; ref7 = 0; c4 = 0; c7 = 0; check;
        #3 rst_n = 1;
        @(negedge clk);
        hold(1, 9); hold(0, 9);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
