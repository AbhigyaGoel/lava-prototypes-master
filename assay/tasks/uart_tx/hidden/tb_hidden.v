`timescale 1ns/1ps
module tb;
    localparam C = 4;
    reg clk = 0, rst_n = 1, tx_start = 0;
    reg [7:0] tx_data = 0;
    wire tx, busy;
    integer errors = 0, i;

    // reference model
    reg       ref_busy;
    integer   ref_cnt;
    reg [9:0] ref_frame;
    reg       exp_tx;

    uart_tx #(.CLKS_PER_BIT(C)) dut (.clk(clk), .rst_n(rst_n), .tx_start(tx_start),
                                     .tx_data(tx_data), .tx(tx), .busy(busy));
    always #5 clk = ~clk;
    initial begin #5000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        begin
            exp_tx = ref_busy ? ref_frame[ref_cnt / C] : 1'b1;
            if (tx !== exp_tx || busy !== ref_busy) begin
                $display("FAIL: t=%0t cnt=%0d tx=%b busy=%b expected tx=%b busy=%b",
                         $time, ref_cnt, tx, busy, exp_tx, ref_busy);
                errors = errors + 1;
            end
        end
    endtask

    task reset_model;
        begin ref_busy = 0; ref_cnt = 0; ref_frame = 10'h3FF; end
    endtask

    // inputs set before the call (away from the edge); one rising edge; update model; check
    task step;
        reg s; reg [7:0] d;
        begin
            s = tx_start; d = tx_data;
            @(posedge clk); #1;
            if (ref_busy) begin
                ref_cnt = ref_cnt + 1;
                if (ref_cnt == 10 * C) ref_busy = 0;
            end else if (s) begin
                ref_busy = 1; ref_cnt = 0; ref_frame = {1'b1, d, 1'b0};
            end
            check;
            @(negedge clk);
        end
    endtask

    initial begin
        reset_model;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        @(negedge clk);
        // idle line after reset
        for (i = 0; i < 6; i = i + 1) step;
        // one frame; tx_start re-asserted with different data in every phase of it
        tx_start = 1; tx_data = 8'h96; step;
        for (i = 0; i < 10 * C + 3; i = i + 1) begin
            tx_start = (i % 3 == 0); tx_data = ~tx_data + i; step;
        end
        tx_start = 0;
        for (i = 0; i < 4; i = i + 1) step;
        // tx_start held high: back-to-back frames, data changing every cycle
        tx_start = 1;
        for (i = 0; i < 3 * (10 * C + 1) + 5; i = i + 1) begin tx_data = $random; step; end
        tx_start = 0;
        for (i = 0; i < 4; i = i + 1) step;
        // all-zero and all-one bytes
        tx_start = 1; tx_data = 8'h00; step; tx_start = 0;
        for (i = 0; i < 10 * C + 2; i = i + 1) step;
        tx_start = 1; tx_data = 8'hFF; step; tx_start = 0;
        for (i = 0; i < 10 * C + 2; i = i + 1) step;
        // random
        for (i = 0; i < 6000; i = i + 1) begin
            tx_start = (($random & 7) == 0); tx_data = $random; step;
        end
        // async reset mid-frame, then idle check
        tx_start = 1; tx_data = 8'h0F; step; tx_start = 0;
        for (i = 0; i < 13; i = i + 1) step;
        rst_n = 0; #1 reset_model; check; #2 rst_n = 1;
        for (i = 0; i < 8; i = i + 1) step;
        tx_start = 1; tx_data = 8'hC3; step; tx_start = 0;
        for (i = 0; i < 10 * C + 4; i = i + 1) step;
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
