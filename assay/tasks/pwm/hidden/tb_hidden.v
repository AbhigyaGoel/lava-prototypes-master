`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] duty = 0;
    wire pwm_out;
    integer errors = 0, i;
    reg [7:0] cnt_ref, dq_ref;

    pwm dut (.clk(clk), .rst_n(rst_n), .duty(duty), .pwm_out(pwm_out));
    always #5 clk = ~clk;
    initial begin #20000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (pwm_out !== (cnt_ref < dq_ref)) begin
            $display("FAIL: t=%0t cnt=%0d duty_q=%0d pwm_out=%b expected=%b",
                     $time, cnt_ref, dq_ref, pwm_out, cnt_ref < dq_ref);
            errors = errors + 1;
        end
    endtask

    task step;
        begin
            #1 check;
            @(posedge clk);
            if (cnt_ref == 8'hFF) dq_ref = duty;
            cnt_ref = cnt_ref + 8'd1;
            #1 check;
            @(negedge clk);
        end
    endtask

    task periods_const(input [7:0] d, input integer n);
        integer k;
        begin
            duty = d;
            for (k = 0; k < 256 * n; k = k + 1) step;
        end
    endtask

    initial begin
        cnt_ref = 0; dq_ref = 0;
        duty = 8'd77;
        #1 rst_n = 0;
        #2 check;
        @(negedge clk) rst_n = 1;
        // first period after reset must be all low; then corner duties
        periods_const(8'd77, 2);
        periods_const(8'd0, 2);
        periods_const(8'd255, 2);
        periods_const(8'd1, 2);
        periods_const(8'd128, 2);
        // duty changing every cycle: only the value at the boundary edge matters
        for (i = 0; i < 256 * 8; i = i + 1) begin
            duty = $random;
            step;
        end
        // duty changes right around the boundary
        for (i = 0; i < 256 * 6; i = i + 1) begin
            if (cnt_ref >= 8'd250 || cnt_ref <= 8'd4) duty = $random;
            step;
        end
        // async reset mid-period
        for (i = 0; i < 37; i = i + 1) step;
        #2 rst_n = 0; #1 cnt_ref = 0; dq_ref = 0; check;
        #3 rst_n = 1;
        @(negedge clk);
        periods_const(8'd200, 2);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
