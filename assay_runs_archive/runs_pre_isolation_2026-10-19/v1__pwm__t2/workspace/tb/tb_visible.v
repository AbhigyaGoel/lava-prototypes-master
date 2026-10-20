`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] duty = 0;
    wire pwm_out;
    integer errors = 0, i, highs;

    pwm dut (.clk(clk), .rst_n(rst_n), .duty(duty), .pwm_out(pwm_out));
    always #5 clk = ~clk;
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    task measure(input [7:0] d);
        begin
            duty = d;
            // let the new duty get latched, then count over one full period
            repeat (256) @(negedge clk);
            highs = 0;
            for (i = 0; i < 256; i = i + 1) begin
                @(negedge clk);
                if (pwm_out === 1'b1) highs = highs + 1;
            end
            if (highs !== d) begin
                $display("FAIL: duty=%0d measured %0d high cycles", d, highs);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        @(negedge clk);
        measure(8'd100);
        measure(8'd200);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
