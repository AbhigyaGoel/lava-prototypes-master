`timescale 1ns/1ps
module tb;
    reg        clk = 0, rst_n = 1;
    reg        in_valid = 0, credit_return = 0;
    reg  [7:0] in_data = 0;
    reg  [1:0] credit_count = 0;
    wire       in_ready, tx_valid, can_send, credit_err;
    wire [7:0] tx_data;
    wire [2:0] credits;
    wire [15:0] beats_sent;
    integer errors = 0, i;

    credit_tx dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data), .in_ready(in_ready),
                   .tx_valid(tx_valid), .tx_data(tx_data), .credit_return(credit_return),
                   .credit_count(credit_count), .can_send(can_send), .credits(credits),
                   .credit_err(credit_err), .beats_sent(beats_sent));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_credits(input [2:0] c);
        if (credits !== c || can_send !== (c != 0) || in_ready !== (c != 0) || credit_err !== 1'b0) begin
            $display("FAIL: t=%0t credits=%0d can_send=%b in_ready=%b err=%b expected credits=%0d",
                     $time, credits, can_send, in_ready, credit_err, c);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #2 expect_credits(7);
        if (tx_valid !== 1'b0) begin $display("FAIL: tx_valid after reset"); errors = errors + 1; end
        @(negedge clk); rst_n = 1;
        // stream until credits run out
        for (i = 0; i < 9; i = i + 1) begin
            expect_credits(i < 7 ? 7 - i : 0);
            in_valid = 1; in_data = 8'h30 + i;
            @(posedge clk); #1;
            if (i < 7 && (tx_valid !== 1'b1 || tx_data !== 8'h30 + i)) begin
                $display("FAIL: beat %0d tx_valid=%b tx_data=%h", i, tx_valid, tx_data);
                errors = errors + 1;
            end
            if (i >= 7 && tx_valid !== 1'b0) begin
                $display("FAIL: sent without credit at step %0d", i); errors = errors + 1;
            end
            @(negedge clk);
        end
        in_valid = 0;
        if (beats_sent !== 16'd7) begin $display("FAIL: beats_sent=%0d", beats_sent); errors = errors + 1; end
        // receiver returns credits while the source is idle
        credit_return = 1; credit_count = 3;
        @(negedge clk); credit_count = 2;
        @(negedge clk); credit_return = 0; credit_count = 0;
        expect_credits(5);
        // one more beat
        in_valid = 1; in_data = 8'hEE;
        @(negedge clk); in_valid = 0;
        expect_credits(4);
        if (tx_valid !== 1'b1 || tx_data !== 8'hEE) begin
            $display("FAIL: last beat tx_valid=%b tx_data=%h", tx_valid, tx_data); errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
