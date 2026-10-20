`timescale 1ns/1ps
module tb;
    reg  [3:0] hex;
    reg        blank;
    wire [6:0] seg;
    integer errors = 0;

    seg7_decoder dut (.hex(hex), .blank(blank), .seg(seg));
    initial begin #10000 $display("ERROR: watchdog timeout"); $finish; end

    task check(input [3:0] h, input b, input [6:0] exp);
        begin
            hex = h; blank = b; #1;
            if (seg !== exp) begin
                $display("FAIL: hex=%h blank=%b seg=%b expected=%b", h, b, seg, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check(4'h0, 0, 7'b1000000);
        check(4'h1, 0, 7'b1111001);
        check(4'h2, 0, 7'b0100100);
        check(4'h3, 0, 7'b0110000);
        check(4'h8, 0, 7'b0000000);
        check(4'hA, 0, 7'b0001000);
        check(4'hF, 0, 7'b0001110);
        check(4'h8, 1, 7'b1111111);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
