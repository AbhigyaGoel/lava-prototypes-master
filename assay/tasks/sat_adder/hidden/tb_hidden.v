`timescale 1ns/1ps
module tb;
    reg  [7:0] a = 0, b = 0;
    reg        sub = 0;
    wire [7:0] y;
    wire       sat;
    integer errors = 0, ia, ib, is, r;
    reg [7:0] ey; reg es;

    sat_adder dut (.a(a), .b(b), .sub(sub), .y(y), .sat(sat));
    initial begin #10000000 $display("ERROR: watchdog timeout"); $finish; end

    initial begin
        for (is = 0; is < 2; is = is + 1)
            for (ia = 0; ia < 256; ia = ia + 1)
                for (ib = 0; ib < 256; ib = ib + 1) begin
                    sub = is; a = ia; b = ib; #1;
                    r = is ? ($signed(a) - $signed(b)) : ($signed(a) + $signed(b));
                    if (r > 127)       begin ey = 8'h7F; es = 1; end
                    else if (r < -128) begin ey = 8'h80; es = 1; end
                    else               begin ey = r[7:0]; es = 0; end
                    if (y !== ey || sat !== es) begin
                        if (errors < 20)
                            $display("FAIL: sub=%b a=%0d b=%0d y=%0d sat=%b expected y=%0d sat=%b",
                                     sub, $signed(a), $signed(b), $signed(y), sat, $signed(ey), es);
                        errors = errors + 1;
                    end
                end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
