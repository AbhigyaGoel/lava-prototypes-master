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
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (q !== q_ref || sout !== (dir ? q_ref[0] : q_ref[7])) begin
            $display("FAIL: t=%0t en=%b load=%b dir=%b q=%h sout=%b expected q=%h sout=%b",
                     $time, en, load, dir, q, sout, q_ref, dir ? q_ref[0] : q_ref[7]);
            errors = errors + 1;
        end
    endtask

    task step;
        begin
            #1 check;
            @(posedge clk); #1;
            if (load) q_ref = d;
            else if (en) q_ref = dir ? {sin, q_ref[7:1]} : {q_ref[6:0], sin};
            check;
            @(negedge clk);
        end
    endtask

    initial begin
        q_ref = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        @(negedge clk);
        // load with en low
        en = 0; load = 1; d = 8'h3C; step;
        load = 0; step;
        // right shift with sin = 1
        en = 1; dir = 1; sin = 1;
        for (i = 0; i < 9; i = i + 1) step;
        // left shift with sin = 0 / 1 alternating
        dir = 0;
        for (i = 0; i < 9; i = i + 1) begin sin = i[0]; step; end
        // load overrides shift, with and without en
        load = 1; d = 8'h81; en = 1; step;
        load = 1; d = 8'h7E; en = 0; step;
        load = 0;
        // randomized
        for (i = 0; i < 2000; i = i + 1) begin
            en = $random; dir = $random; sin = $random; d = $random;
            load = (($random & 7) == 0);
            step;
        end
        // async reset mid-operation
        #2 rst_n = 0; #1 q_ref = 0; check;
        #3 rst_n = 1;
        @(negedge clk);
        en = 1; load = 0; dir = 1; sin = 1;
        for (i = 0; i < 10; i = i + 1) step;
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
