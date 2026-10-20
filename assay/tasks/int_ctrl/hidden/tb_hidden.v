`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [7:0] src = 0;
    reg we = 0, ack = 0;
    reg [1:0] addr = 0;
    reg [7:0] wdata = 0;
    reg [2:0] ack_id = 0;
    wire [7:0] pending;
    wire irq;
    wire [2:0] irq_id;
    integer errors = 0, n, k;

    // reference model state
    reg [7:0] m_mask, m_mode, m_srcq, m_ep;
    reg [7:0] e_pend, e_act;
    reg       e_irq;
    reg [2:0] e_id;

    int_ctrl dut (.clk(clk), .rst_n(rst_n), .src(src), .we(we), .addr(addr), .wdata(wdata),
                  .ack(ack), .ack_id(ack_id), .pending(pending), .irq(irq), .irq_id(irq_id));
    always #5 clk = ~clk;
    initial begin #5000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_mask = 0; m_mode = 0; m_srcq = 0; m_ep = 0; end
    endtask

    task expect_outputs;
        begin
            e_pend = (m_mode & m_ep) | (~m_mode & src);
            e_act  = e_pend & m_mask;
            e_irq  = |e_act;
            e_id   = 3'd0;
            for (k = 7; k >= 0; k = k - 1) if (e_act[k]) e_id = k;
        end
    endtask

    // drive at negedge, check combinational outputs, update the model at posedge
    task cycle(input [7:0] s, input w, input [1:0] ad, input [7:0] wd, input a, input [2:0] aid);
        begin
            @(negedge clk);
            src = s; we = w; addr = ad; wdata = wd; ack = a; ack_id = aid;
            #1;
            expect_outputs;
            if (pending !== e_pend || irq !== e_irq || irq_id !== e_id) begin
                if (errors < 20)
                    $display("FAIL: t=%0t src=%h mode=%h mask=%h ack=%b/%0d pending=%h irq=%b id=%0d expected pending=%h irq=%b id=%0d",
                             $time, src, m_mode, m_mask, ack, ack_id, pending, irq, irq_id, e_pend, e_irq, e_id);
                errors = errors + 1;
            end
            @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin
                if (!m_mode[k])                       m_ep[k] = 1'b0;
                else if (src[k] && !m_srcq[k])        m_ep[k] = 1'b1;
                else if (ack && ack_id == k)          m_ep[k] = 1'b0;
            end
            m_srcq = src;
            if (we && addr == 2'd0) m_mask = wdata;
            if (we && addr == 2'd1) m_mode = wdata;
        end
    endtask

    task idle(input [7:0] s);
        cycle(s, 0, 0, 0, 0, 0);
    endtask

    initial begin
        model_reset;
        #1 rst_n = 0;
        #11 rst_n = 1;
        idle(0);
        // configure: all edge, all enabled
        cycle(0, 1, 1, 8'hFF, 0, 0);
        cycle(0, 1, 0, 8'hFF, 0, 0);
        // priority: several pending, lowest index wins
        idle(8'hA4); idle(8'h00); idle(8'h00);
        cycle(0, 0, 0, 0, 1, 3'd2); idle(0); cycle(0, 0, 0, 0, 1, 3'd5); idle(0);
        cycle(0, 0, 0, 0, 1, 3'd7); idle(0);
        // rising edge and acknowledge of the same source in the same cycle
        cycle(8'h08, 0, 0, 0, 1, 3'd3); idle(0); idle(0);
        cycle(0, 0, 0, 0, 1, 3'd3); idle(0);
        cycle(8'h08, 0, 0, 0, 1, 3'd3); cycle(8'h00, 0, 0, 0, 1, 3'd3); idle(0);
        // pending edge source switched to level and back must not resurrect
        idle(8'h10); idle(8'h00);
        cycle(0, 1, 1, 8'h00, 0, 0); idle(0); idle(8'h10); idle(0);
        cycle(0, 1, 1, 8'hFF, 0, 0); idle(0); idle(0);
        // level sources mixed with edge sources
        cycle(0, 1, 1, 8'h0F, 0, 0);
        idle(8'hF0); idle(8'hF1); idle(8'hF0); cycle(8'hF0, 0, 0, 0, 1, 3'd0); idle(8'h30); idle(0);
        cycle(8'h40, 0, 0, 0, 1, 3'd6); idle(8'h40); idle(0);
        // masked sources still latch
        cycle(0, 1, 0, 8'hF0, 0, 0); idle(8'h01); idle(0);
        cycle(0, 1, 0, 8'hFF, 0, 0); idle(0); cycle(0, 0, 0, 0, 1, 3'd0); idle(0);
        // reserved address writes are ignored
        cycle(0, 1, 2, 8'h00, 0, 0); cycle(0, 1, 3, 8'h00, 0, 0); idle(8'h22); idle(0);
        // long random run
        for (n = 0; n < 20000; n = n + 1) begin
            expect_outputs;
            cycle(src ^ ($random & $random & $random),
                  ($random % 8) == 0, $random, $random,
                  ($random % 2) == 0, (($random % 4) != 0) ? e_id : $random);
        end
        // asynchronous reset mid-run
        idle(8'hFF);
        @(negedge clk); src = 0; we = 0; ack = 0; rst_n = 0; #1 model_reset; #2 rst_n = 1;
        for (n = 0; n < 2000; n = n + 1) begin
            expect_outputs;
            cycle(src ^ ($random & $random), ($random % 6) == 0, $random, $random,
                  ($random % 3) == 0, (($random % 2) != 0) ? e_id : $random);
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
