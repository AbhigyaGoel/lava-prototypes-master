`timescale 1ns/1ps
module tb;
    reg  [7:0] a = 0, b = 0;
    reg  [2:0] op = 0;
    wire [7:0] y;
    wire zero, carry, overflow;
    integer errors = 0;

    alu dut (.a(a), .b(b), .op(op), .y(y), .zero(zero), .carry(carry), .overflow(overflow));
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check_y(input [2:0] o, input [7:0] ia, input [7:0] ib, input [7:0] ey);
        begin
            op = o; a = ia; b = ib; #1;
            if (y !== ey || zero !== (ey == 8'd0)) begin
                $display("FAIL: op=%0d a=%h b=%h y=%h zero=%b expected y=%h", o, ia, ib, y, zero, ey);
                errors = errors + 1;
            end
        end
    endtask

    task check_flag(input [8*8-1:0] name, input got, input exp);
        if (got !== exp) begin
            $display("FAIL: %0s op=%0d a=%h b=%h got=%b expected=%b", name, op, a, b, got, exp);
            errors = errors + 1;
        end
    endtask

    initial begin
        // ADD
        check_y(3'd0, 8'd3, 8'd4, 8'd7);       check_flag("carry", carry, 0); check_flag("ovf", overflow, 0);
        check_y(3'd0, 8'd200, 8'd100, 8'd44);  check_flag("carry", carry, 1); check_flag("ovf", overflow, 0);
        check_y(3'd0, 8'd100, 8'd100, 8'd200); check_flag("carry", carry, 0); check_flag("ovf", overflow, 1);
        check_y(3'd0, 8'hFF, 8'h01, 8'h00);    check_flag("carry", carry, 1);
        // SUB
        check_y(3'd1, 8'd10, 8'd3, 8'd7);      check_flag("carry", carry, 0);
        check_y(3'd1, 8'd3, 8'd10, 8'hF9);     check_flag("carry", carry, 1);
        check_y(3'd1, 8'd42, 8'd42, 8'd0);     check_flag("carry", carry, 0);
        // logic
        check_y(3'd2, 8'hF0, 8'h3C, 8'h30);
        check_y(3'd3, 8'hF0, 8'h0C, 8'hFC);
        check_y(3'd4, 8'hFF, 8'h0F, 8'hF0);
        check_y(3'd4, 8'h5A, 8'h5A, 8'h00);
        // shifts
        check_y(3'd5, 8'h01, 8'd3, 8'h08);
        check_y(3'd5, 8'h81, 8'd1, 8'h02);
        check_y(3'd6, 8'h80, 8'd7, 8'h01);
        check_y(3'd6, 8'hF0, 8'd4, 8'h0F);
        // SLT
        check_y(3'd7, 8'd3, 8'd5, 8'h01);
        check_y(3'd7, 8'd5, 8'd3, 8'h00);
        check_y(3'd7, 8'd9, 8'd9, 8'h00);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
