`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, din = 0;
    wire rise, fall, any;
    integer errors = 0, i;
    integer n_rise, n_fall, n_any;

    edge_detector dut (.clk(clk), .rst_n(rst_n), .din(din), .rise(rise), .fall(fall), .any(any));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    always @(posedge clk) begin
        if (rise) n_rise = n_rise + 1;
        if (fall) n_fall = n_fall + 1;
        if (any)  n_any  = n_any  + 1;
    end

    task pulse_count(input integer er, input integer ef, input integer ea);
        begin
            if (n_rise !== er || n_fall !== ef || n_any !== ea) begin
                $display("FAIL: rise=%0d fall=%0d any=%0d expected %0d %0d %0d",
                         n_rise, n_fall, n_any, er, ef, ea);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        n_rise = 0; n_fall = 0; n_any = 0;
        #1 rst_n = 0;
        #11 rst_n = 1;
        repeat (3) @(posedge clk);
        #1 n_rise = 0; n_fall = 0; n_any = 0;
        // a few slow toggles
        for (i = 0; i < 3; i = i + 1) begin
            #2 din = 1;
            repeat (6) @(posedge clk);
            #2 din = 0;
            repeat (6) @(posedge clk);
        end
        pulse_count(3, 3, 6);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
