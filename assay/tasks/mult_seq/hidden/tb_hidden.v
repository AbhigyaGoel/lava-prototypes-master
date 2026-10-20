`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0;
    reg [7:0] a = 0, b = 0;
    wire busy, done;
    wire [15:0] product;
    integer errors = 0, i, j, ops = 0;

    // reference model
    reg        m_busy, m_done;
    reg [15:0] m_prod;
    integer    m_cnt, m_a, m_b;

    mult_seq dut (.clk(clk), .rst_n(rst_n), .start(start), .a(a), .b(b),
                  .busy(busy), .done(done), .product(product));
    always #5 clk = ~clk;
    initial begin #20000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_busy = 0; m_done = 0; m_prod = 0; m_cnt = 0; m_a = 0; m_b = 0; end
    endtask

    // drive at negedge, check registered outputs, update the model at posedge
    task cycle(input st, input [7:0] av, input [7:0] bv);
        begin
            @(negedge clk);
            if (busy !== m_busy || done !== m_done || product !== m_prod) begin
                if (errors < 20)
                    $display("FAIL: t=%0t op=%0d*%0d busy=%b done=%b product=%h expected busy=%b done=%b product=%h",
                             $time, m_a, m_b, busy, done, product, m_busy, m_done, m_prod);
                errors = errors + 1;
            end
            start = st; a = av; b = bv;
            @(posedge clk);
            m_done = 0;
            if (!m_busy && st) begin
                m_busy = 1; m_cnt = 0; m_a = $signed(av); m_b = $signed(bv); ops = ops + 1;
            end else if (m_busy) begin
                m_cnt = m_cnt + 1;
                if (m_cnt == 8) begin
                    m_busy = 0; m_done = 1; m_prod = m_a * m_b;
                end
            end
        end
    endtask

    // one operation; while busy, start is toggled randomly with random operands
    task op(input [7:0] av, input [7:0] bv);
        begin
            cycle(1, av, bv);
            while (m_busy) cycle(($random % 3) == 0, $random, $random);
        end
    endtask

    task op_quiet(input [7:0] av, input [7:0] bv);
        begin
            cycle(1, av, bv);
            while (m_busy) cycle(0, 0, 0);
            cycle(0, 0, 0); cycle(0, 0, 0);
        end
    endtask

    initial begin
        model_reset;
        #1 rst_n = 0;
        #11 rst_n = 1;
        cycle(0, 0, 0);
        // directed extremes, with idle gaps
        op_quiet(8'h80, 8'h80); op_quiet(8'h80, 8'h7F); op_quiet(8'h7F, 8'h80);
        op_quiet(8'h7F, 8'h7F); op_quiet(8'hFF, 8'hFF); op_quiet(8'h80, 8'h00);
        op_quiet(8'h00, 8'h80); op_quiet(8'h80, 8'hFF); op_quiet(8'hFF, 8'h80);
        op_quiet(8'h80, 8'h01); op_quiet(8'h01, 8'h80); op_quiet(8'h03, 8'h05);
        // start held high: back-to-back operations, start ignored while busy
        for (i = 0; i < 40; i = i + 1) cycle(1, $random, $random);
        // full rows/columns for the extreme operands
        for (i = 0; i < 256; i = i + 1) begin
            op(8'h80, i); op(i, 8'h80); op(8'h7F, i); op(i, 8'h7F);
            op(8'hFF, i); op(i, 8'hFF); op(8'h81, i); op(i, 8'h01);
        end
        // random operands
        for (i = 0; i < 3000; i = i + 1) op($random, $random);
        // random start activity
        for (i = 0; i < 4000; i = i + 1) cycle($random, $random, $random);
        // asynchronous reset in the middle of an operation
        cycle(1, 8'h80, 8'h80); cycle(0, 0, 0); cycle(0, 0, 0);
        @(negedge clk); start = 0; rst_n = 0; #1 model_reset; #2 rst_n = 1;
        for (i = 0; i < 300; i = i + 1) op($random, $random);
        for (j = 0; j < 12; j = j + 1) cycle(0, 0, 0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
