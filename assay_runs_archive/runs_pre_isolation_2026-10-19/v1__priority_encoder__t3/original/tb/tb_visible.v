`timescale 1ns/1ps
module tb;
    reg  [7:0] in = 0;
    wire [2:0] y;
    wire valid;
    integer errors = 0;

    priority_encoder dut (.in(in), .y(y), .valid(valid));
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check(input [7:0] v, input [2:0] exp_y);
        begin
            in = v; #1;
            if (valid !== 1'b1 || y !== exp_y) begin
                $display("FAIL: in=%b y=%0d valid=%b expected y=%0d valid=1", v, y, valid, exp_y);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check(8'h01, 3'd0);
        check(8'h02, 3'd1);
        check(8'h06, 3'd2);
        check(8'h10, 3'd4);
        check(8'h25, 3'd5);
        check(8'h40, 3'd6);
        check(8'h80, 3'd7);
        check(8'hFF, 3'd7);
        in = 8'h00; #1;
        if (valid !== 1'b0) begin
            $display("FAIL: in=0 valid=%b expected 0", valid);
            errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
