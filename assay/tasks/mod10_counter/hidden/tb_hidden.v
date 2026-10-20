`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, en = 0, load = 0;
    reg [3:0] d = 0;
    wire [3:0] q;
    wire co;
    integer errors = 0, i;
    reg [3:0] q_ref;

    mod10_counter dut (.clk(clk), .rst_n(rst_n), .en(en), .load(load), .d(d), .q(q), .co(co));
    always #5 clk = ~clk;
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    task check_q;
        if (q !== q_ref) begin
            $display("FAIL: t=%0t q=%0d expected=%0d", $time, q, q_ref);
            errors = errors + 1;
        end
    endtask

    task check_co;
        if (co !== (en && !load && q_ref == 4'd9)) begin
            $display("FAIL: t=%0t co=%b en=%b load=%b q=%0d", $time, co, en, load, q);
            errors = errors + 1;
        end
    endtask

    task step;
        begin
            #1 check_co;
            @(posedge clk); #1;
            if (load) q_ref = (d > 4'd9) ? 4'd0 : d;
            else if (en) q_ref = (q_ref == 4'd9) ? 4'd0 : q_ref + 4'd1;
            check_q;
            @(negedge clk);
        end
    endtask

    initial begin
        q_ref = 0;
        #1 rst_n = 0;
        #2 check_q;
        #9 rst_n = 1;
        @(negedge clk);
        // directed: count through wrap
        en = 1;
        for (i = 0; i < 22; i = i + 1) step;
        // directed: load while q == 9, with and without en
        load = 1; d = 4'd9; step;
        load = 1; d = 4'd9; en = 1; step;
        load = 1; d = 4'd5; en = 0; step;
        // load invalid BCD values
        for (i = 10; i < 16; i = i + 1) begin
            load = 1; d = i; en = i[0]; step;
            load = 0; en = 1; step;
        end
        // reach 9 with en low (co must be low)
        load = 1; d = 4'd9; en = 0; step;
        load = 0; en = 0; step; step;
        en = 1; step;
        // randomized
        for (i = 0; i < 2000; i = i + 1) begin
            en = $random;
            load = (($random & 7) == 0);
            d = $random;
            if (q_ref == 4'd9 && ($random & 1)) load = 1;
            step;
        end
        // async reset mid-count
        #2 rst_n = 0; #1 q_ref = 0; check_q;
        #3 rst_n = 1;
        @(negedge clk);
        en = 1; load = 0;
        for (i = 0; i < 15; i = i + 1) step;
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
