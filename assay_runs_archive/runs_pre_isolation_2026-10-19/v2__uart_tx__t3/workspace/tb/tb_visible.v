`timescale 1ns/1ps
module tb;
    localparam C = 4;
    reg clk = 0, rst_n = 1, tx_start = 0;
    reg [7:0] tx_data = 0;
    wire tx, busy;
    integer errors = 0, k;

    uart_tx #(.CLKS_PER_BIT(C)) dut (.clk(clk), .rst_n(rst_n), .tx_start(tx_start),
                                     .tx_data(tx_data), .tx(tx), .busy(busy));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task send_and_check(input [7:0] b);
        reg [9:0] frame;
        begin
            frame = {1'b1, b, 1'b0};
            @(negedge clk); tx_start = 1; tx_data = b;
            @(negedge clk); tx_start = 0;
            if (busy !== 1'b1) begin $display("FAIL: busy not set"); errors = errors + 1; end
            // now 0.5 cycle after the accepting edge; move to the middle of each bit
            repeat (C / 2) @(negedge clk);
            for (k = 0; k < 10; k = k + 1) begin
                if (tx !== frame[k]) begin
                    $display("FAIL: byte %h bit %0d tx=%b expected=%b", b, k, tx, frame[k]);
                    errors = errors + 1;
                end
                repeat (C) @(negedge clk);
            end
            if (busy !== 1'b0) begin $display("FAIL: busy still set after frame"); errors = errors + 1; end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        repeat (3) @(negedge clk);
        send_and_check(8'hA5);
        repeat (2) @(negedge clk);
        send_and_check(8'h3C);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
