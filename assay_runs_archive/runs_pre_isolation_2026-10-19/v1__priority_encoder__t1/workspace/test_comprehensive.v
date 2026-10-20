`timescale 1ns/1ps
module test;
    reg  [7:0] in;
    wire [2:0] y;
    wire valid;
    integer errors = 0;
    
    priority_encoder dut (.in(in), .y(y), .valid(valid));
    
    task check(input [7:0] v, input [2:0] exp_y, input exp_valid);
        begin
            in = v; #1;
            if (y !== exp_y || valid !== exp_valid) begin
                $display("FAIL: in=%b y=%d valid=%b expected y=%d valid=%b", v, y, valid, exp_y, exp_valid);
                errors = errors + 1;
            end else begin
                $display("PASS: in=%b y=%d valid=%b", v, y, valid);
            end
        end
    endtask
    
    initial begin
        check(8'h00, 3'd0, 1'b0);
        check(8'h01, 3'd0, 1'b1);
        check(8'h02, 3'd1, 1'b1);
        check(8'h04, 3'd2, 1'b1);
        check(8'h08, 3'd3, 1'b1);
        check(8'h10, 3'd4, 1'b1);
        check(8'h20, 3'd5, 1'b1);
        check(8'h40, 3'd6, 1'b1);
        check(8'h80, 3'd7, 1'b1);
        check(8'hFF, 3'd7, 1'b1);
        
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("TESTS FAILED: %0d errors", errors);
        $finish;
    end
endmodule
