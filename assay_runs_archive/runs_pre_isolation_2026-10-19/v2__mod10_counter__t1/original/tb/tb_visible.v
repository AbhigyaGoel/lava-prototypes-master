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
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        en = 1;
        q_ref = 0;
        for (i = 0; i < 25; i = i + 1) begin
            #1;
            if (co !== (q_ref == 4'd9)) begin
                $display("FAIL: step %0d co=%b q=%0d", i, co, q);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            q_ref = (q_ref == 4'd9) ? 4'd0 : q_ref + 4'd1;
            if (q !== q_ref) begin
                $display("FAIL: step %0d q=%0d expected=%0d", i, q, q_ref);
                errors = errors + 1;
            end
            @(negedge clk);
        end
        // load a value
        load = 1; d = 4'd3;
        @(posedge clk); #1;
        if (q !== 4'd3) begin
            $display("FAIL: load q=%0d expected=3", q);
            errors = errors + 1;
        end
        @(negedge clk) load = 0; en = 0;
        @(posedge clk); #1;
        if (q !== 4'd3) begin
            $display("FAIL: hold q=%0d expected=3", q);
            errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
