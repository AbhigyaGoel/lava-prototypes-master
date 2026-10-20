`timescale 1ns/1ps
module tb;
    reg  [7:0] a = 0, b = 0;
    reg        sub = 0;
    wire [7:0] y;
    wire       sat;
    integer errors = 0;

    sat_adder dut (.a(a), .b(b), .sub(sub), .y(y), .sat(sat));
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check(input s, input [7:0] ia, input [7:0] ib, input [7:0] ey, input es);
        begin
            sub = s; a = ia; b = ib; #1;
            if (y !== ey || sat !== es) begin
                $display("FAIL: sub=%b a=%0d b=%0d y=%0d sat=%b expected y=%0d sat=%b",
                         s, $signed(ia), $signed(ib), $signed(y), sat, $signed(ey), es);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check(0, 8'd10, 8'd20, 8'd30, 0);
        check(0, -8'sd5, 8'd3, -8'sd2, 0);
        check(0, 8'd100, 8'd100, 8'h7F, 1);
        check(0, -8'sd100, -8'sd100, 8'h80, 1);
        check(1, 8'd50, 8'd20, 8'd30, 0);
        check(1, 8'd20, 8'd50, -8'sd30, 0);
        check(1, 8'd100, -8'sd100, 8'h7F, 1);
        check(1, -8'sd100, 8'd100, 8'h80, 1);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
