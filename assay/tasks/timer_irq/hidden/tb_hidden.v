`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg load = 0, en = 0, auto_reload = 0, irq_clr = 0;
    reg [15:0] load_val = 0;
    wire [15:0] count;
    wire irq;
    integer errors = 0, i, k;

    reg [15:0] m_count, m_reload;
    reg m_irq, m_exp;

    timer_irq dut (.clk(clk), .rst_n(rst_n), .load(load), .load_val(load_val), .en(en),
                   .auto_reload(auto_reload), .irq_clr(irq_clr), .count(count), .irq(irq));
    always #5 clk = ~clk;
    initial begin #5000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (count !== m_count || irq !== m_irq) begin
            if (errors < 20)
                $display("FAIL: t=%0t count=%0d irq=%b expected count=%0d irq=%b",
                         $time, count, irq, m_count, m_irq);
            errors = errors + 1;
        end
    endtask

    // apply inputs at negedge, advance the reference model at posedge, check after
    task cycle(input ld, input [15:0] lv, input e, input ar, input clr);
        begin
            @(negedge clk);
            load = ld; load_val = lv; en = e; auto_reload = ar; irq_clr = clr;
            @(posedge clk);
            m_exp = 0;
            if (ld) begin m_count = lv; m_reload = lv; end
            else if (e && m_count != 0) begin
                if (m_count == 1) begin m_exp = 1; m_count = ar ? m_reload : 16'd0; end
                else m_count = m_count - 1;
            end
            if (m_exp) m_irq = 1;
            else if (clr) m_irq = 0;
            #1 check;
        end
    endtask

    initial begin
        m_count = 0; m_reload = 0; m_irq = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        // auto-reload period 3, clear every cycle (clear coincides with expiry)
        cycle(1, 3, 0, 1, 0);
        for (i = 0; i < 12; i = i + 1) cycle(0, 0, 1, 1, 1);
        // auto-reload period 1
        cycle(1, 1, 0, 1, 0);
        for (i = 0; i < 6; i = i + 1) cycle(0, 0, 1, 1, i[0]);
        // auto-reload period 4, clear exactly at expiry
        cycle(1, 4, 1, 1, 1);
        for (i = 0; i < 16; i = i + 1) cycle(0, 0, 1, 1, (i % 4) == 3);
        // switch to one-shot mid-run
        for (i = 0; i < 8; i = i + 1) cycle(0, 0, 1, 0, 0);
        cycle(0, 0, 1, 0, 1);
        // load with value 0 and load during expiry
        cycle(1, 0, 1, 1, 0); cycle(0, 0, 1, 1, 0);
        cycle(1, 2, 1, 1, 0); cycle(0, 0, 1, 1, 0); cycle(1, 5, 1, 1, 0); cycle(0, 0, 1, 1, 0);
        // random, small load values so expiries are frequent
        for (i = 0; i < 6000; i = i + 1)
            cycle(($random % 16) == 0, $random % 8, ($random % 5) != 0, $random, ($random % 3) == 0);
        // random, larger loads
        for (k = 0; k < 4; k = k + 1) begin
            cycle(1, 40 + k * 17, 1, k[0], 0);
            for (i = 0; i < 300; i = i + 1)
                cycle(0, 0, ($random % 8) != 0, k[0], ($random % 7) == 0);
        end
        // wrap check: 16-bit max value
        cycle(1, 16'hFFFF, 1, 0, 0);
        for (i = 0; i < 5; i = i + 1) cycle(0, 0, 1, 0, 0);
        // async reset mid-count
        @(negedge clk); #2 rst_n = 0; #1;
        m_count = 0; m_reload = 0; m_irq = 0; check;
        #1 rst_n = 1;
        cycle(0, 0, 1, 1, 0); cycle(0, 0, 1, 1, 0);
        for (i = 0; i < 2000; i = i + 1)
            cycle(($random % 16) == 0, $random % 8, $random, $random, $random);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
