`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg in_valid = 0, in_last = 0, out_ready = 1;
    reg [7:0] in_data = 0;
    wire in_ready, out_valid, out_last;
    wire [31:0] out_data;
    wire [3:0] out_keep;
    integer errors = 0, i, nw = 0;
    reg [31:0] got_d [0:31];
    reg [3:0]  got_k [0:31];
    reg        got_l [0:31];

    width_packer dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
                      .in_data(in_data), .in_last(in_last), .out_valid(out_valid),
                      .out_ready(out_ready), .out_data(out_data), .out_keep(out_keep),
                      .out_last(out_last));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    // collect delivered words
    always @(posedge clk)
        if (out_valid && out_ready) begin
            got_d[nw] <= out_data; got_k[nw] <= out_keep; got_l[nw] <= out_last; nw <= nw + 1;
        end

    // send one byte, waiting for in_ready
    task send(input [7:0] d, input l);
        begin
            @(negedge clk); in_valid = 1; in_data = d; in_last = l;
            #1; while (in_ready !== 1'b1) begin @(negedge clk); #1; end
            @(posedge clk); #1; in_valid = 0; in_last = 0;
        end
    endtask

    task expect_word(input integer n, input [31:0] d, input [3:0] k, input l);
        if (got_d[n] !== d || got_k[n] !== k || got_l[n] !== l) begin
            $display("FAIL: word %0d = %h keep=%b last=%b, expected %h keep=%b last=%b",
                     n, got_d[n], got_k[n], got_l[n], d, k, l);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        // 8-byte packet: two full words
        for (i = 0; i < 8; i = i + 1) send(8'h10 + i, i == 7);
        // 3-byte packet: partial word
        for (i = 0; i < 3; i = i + 1) send(8'hA0 + i, i == 2);
        // 6-byte packet
        for (i = 0; i < 6; i = i + 1) send(8'hC0 + i, i == 5);
        // 12-byte packet with the sink stalled at the start
        repeat (2) @(negedge clk);
        out_ready = 0;
        for (i = 0; i < 6; i = i + 1) send(8'h50 + i, 1'b0);
        @(negedge clk); out_ready = 1;
        for (i = 6; i < 12; i = i + 1) send(8'h50 + i, i == 11);
        repeat (4) @(negedge clk);
        if (nw != 8) begin $display("FAIL: %0d words delivered, expected 8", nw); errors = errors + 1; end
        expect_word(0, 32'h13121110, 4'b1111, 1'b0);
        expect_word(1, 32'h17161514, 4'b1111, 1'b1);
        expect_word(2, 32'h00A2A1A0, 4'b0111, 1'b1);
        expect_word(3, 32'hC3C2C1C0, 4'b1111, 1'b0);
        expect_word(4, 32'h0000C5C4, 4'b0011, 1'b1);
        expect_word(5, 32'h53525150, 4'b1111, 1'b0);
        expect_word(6, 32'h57565554, 4'b1111, 1'b0);
        expect_word(7, 32'h5B5A5958, 4'b1111, 1'b1);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
