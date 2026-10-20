`timescale 1ns/1ps
module tb;
    reg  [12:0] cw;
    wire [7:0]  data;
    wire        single_err, double_err;
    wire [3:0]  err_pos;
    integer errors = 0;

    hamming_secded dut (.cw(cw), .data(data), .single_err(single_err),
                        .double_err(double_err), .err_pos(err_pos));
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    function [12:0] encode(input [7:0] d);
        reg [12:0] c;
        begin
            c = 13'd0;
            c[3] = d[0]; c[5] = d[1]; c[6] = d[2]; c[7] = d[3];
            c[9] = d[4]; c[10] = d[5]; c[11] = d[6]; c[12] = d[7];
            c[1] = c[3] ^ c[5] ^ c[7] ^ c[9] ^ c[11];
            c[2] = c[3] ^ c[6] ^ c[7] ^ c[10] ^ c[11];
            c[4] = c[5] ^ c[6] ^ c[7] ^ c[12];
            c[8] = c[9] ^ c[10] ^ c[11] ^ c[12];
            c[0] = ^c[12:1];
            encode = c;
        end
    endfunction

    task check(input [12:0] w, input [7:0] d, input s, input dbl, input [3:0] pos);
        begin
            cw = w; #1;
            if (data !== d || single_err !== s || double_err !== dbl || err_pos !== pos) begin
                $display("FAIL: cw=%h data=%h s=%b d=%b pos=%0d expected data=%h s=%b d=%b pos=%0d",
                         w, data, single_err, double_err, err_pos, d, s, dbl, pos);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // clean codewords
        check(encode(8'h00), 8'h00, 0, 0, 0);
        check(encode(8'hA5), 8'hA5, 0, 0, 0);
        check(encode(8'hFF), 8'hFF, 0, 0, 0);
        check(encode(8'h3C), 8'h3C, 0, 0, 0);
        // single-bit errors
        check(encode(8'hA5) ^ 13'h0008, 8'hA5, 1, 0, 3);    // data bit d0
        check(encode(8'hA5) ^ 13'h0080, 8'hA5, 1, 0, 7);    // data bit d3
        check(encode(8'h3C) ^ 13'h1000, 8'h3C, 1, 0, 12);   // data bit d7
        check(encode(8'h3C) ^ 13'h0004, 8'h3C, 1, 0, 2);    // parity P2
        check(encode(8'h3C) ^ 13'h0001, 8'h3C, 1, 0, 0);    // overall parity P0
        // double-bit errors are flagged
        cw = encode(8'h5A) ^ 13'h0006; #1;
        if (double_err !== 1'b1 || single_err !== 1'b0) begin
            $display("FAIL: double error not flagged"); errors = errors + 1;
        end
        cw = encode(8'h5A) ^ 13'h0101; #1;
        if (double_err !== 1'b1 || single_err !== 1'b0) begin
            $display("FAIL: double error not flagged"); errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
