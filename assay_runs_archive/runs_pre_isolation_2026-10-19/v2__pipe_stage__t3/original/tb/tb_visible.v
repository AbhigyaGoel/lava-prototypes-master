`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg in_valid = 0, out_ready = 0;
    reg [7:0] in_data = 0;
    wire in_ready, out_valid;
    wire [7:0] out_data;
    integer errors = 0, i;

    pipe_stage dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
                    .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready),
                    .out_data(out_data));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_out(input v, input [7:0] d);
        if (out_valid !== v || (v && out_data !== d)) begin
            $display("FAIL: t=%0t out_valid=%b out_data=%h expected valid=%b data=%h",
                     $time, out_valid, out_data, v, d);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        if (out_valid !== 1'b0 || in_ready !== 1'b1) begin
            $display("FAIL: bad state after reset"); errors = errors + 1;
        end
        // streaming with the sink always ready
        out_ready = 1;
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk); in_valid = 1; in_data = 8'hA0 + i;
            if (in_ready !== 1'b1) begin $display("FAIL: in_ready low while streaming"); errors = errors + 1; end
            @(posedge clk); #1;
            expect_out(1, 8'hA0 + i);
        end
        @(negedge clk); in_valid = 0;
        @(posedge clk); #1; expect_out(0, 8'h00);
        // single word held while the sink stalls
        @(negedge clk); out_ready = 0; in_valid = 1; in_data = 8'h5C;
        @(negedge clk); in_valid = 0;
        repeat (3) begin
            @(posedge clk); #1; expect_out(1, 8'h5C);
        end
        @(negedge clk); out_ready = 1;
        @(posedge clk); #1; expect_out(0, 8'h00);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
