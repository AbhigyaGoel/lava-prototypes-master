`timescale 1ns/1ps
module tb;
    reg  [7:0] in = 8'hFF;
    wire [2:0] y;
    wire valid;
    integer errors = 0, i, k;
    reg [2:0] y_ref;
    reg v_ref;

    priority_encoder dut (.in(in), .y(y), .valid(valid));
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            in = i; #1;
            y_ref = 3'd0;
            v_ref = 1'b0;
            for (k = 0; k < 8; k = k + 1)
                if (in[k]) begin y_ref = k; v_ref = 1'b1; end
            if (valid !== v_ref || y !== y_ref) begin
                $display("FAIL: in=%b y=%b valid=%b expected y=%b valid=%b", in, y, valid, y_ref, v_ref);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
