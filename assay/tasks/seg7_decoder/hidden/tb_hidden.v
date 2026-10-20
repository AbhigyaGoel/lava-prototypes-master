`timescale 1ns/1ps
module tb;
    reg  [3:0] hex;
    reg        blank;
    wire [6:0] seg;
    integer errors = 0, i;
    reg [6:0] lit;
    reg [6:0] exp;

    seg7_decoder dut (.hex(hex), .blank(blank), .seg(seg));
    initial begin #10000 $display("ERROR: watchdog timeout"); $finish; end

    // reference: lit-segment set as {g,f,e,d,c,b,a}
    function [6:0] ref_lit(input [3:0] h);
        case (h)
            4'h0: ref_lit = {1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1};
            4'h1: ref_lit = {1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b0};
            4'h2: ref_lit = {1'b1,1'b0,1'b1,1'b1,1'b0,1'b1,1'b1};
            4'h3: ref_lit = {1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1};
            4'h4: ref_lit = {1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b0};
            4'h5: ref_lit = {1'b1,1'b1,1'b0,1'b1,1'b1,1'b0,1'b1};
            4'h6: ref_lit = {1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1};
            4'h7: ref_lit = {1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b1};
            4'h8: ref_lit = {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1};
            4'h9: ref_lit = {1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1};
            4'hA: ref_lit = {1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1};
            4'hB: ref_lit = {1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0};
            4'hC: ref_lit = {1'b0,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1};
            4'hD: ref_lit = {1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b0};
            4'hE: ref_lit = {1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1};
            4'hF: ref_lit = {1'b1,1'b1,1'b1,1'b0,1'b0,1'b0,1'b1};
        endcase
    endfunction

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            hex = i[3:0]; blank = i[4]; #1;
            exp = blank ? 7'b1111111 : ~ref_lit(hex);
            if (seg !== exp) begin
                $display("FAIL: hex=%h blank=%b seg=%b expected=%b", hex, blank, seg, exp);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
