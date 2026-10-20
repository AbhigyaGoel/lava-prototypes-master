`timescale 1ns/1ps
module tb;
    reg  [7:0] a = 0, b = 0;
    reg  [2:0] op = 0;
    wire [7:0] y;
    wire zero, carry, overflow;
    integer errors = 0, ia, ib, io;
    reg [7:0] ey; reg ec, eo;
    integer sa, sb, sr;

    alu dut (.a(a), .b(b), .op(op), .y(y), .zero(zero), .carry(carry), .overflow(overflow));
    initial begin #10000000 $display("ERROR: watchdog timeout"); $finish; end

    task model;
        begin
            sa = $signed(a); sb = $signed(b);
            ey = 0; ec = 0; eo = 0;
            case (op)
                3'd0: begin ey = a + b; ec = ({1'b0,a} + {1'b0,b}) > 255; sr = sa + sb; eo = (sr > 127) || (sr < -128); end
                3'd1: begin ey = a - b; ec = (a < b); sr = sa - sb; eo = (sr > 127) || (sr < -128); end
                3'd2: ey = a & b;
                3'd3: ey = a | b;
                3'd4: ey = a ^ b;
                3'd5: ey = a << b[2:0];
                3'd6: ey = a >> b[2:0];
                3'd7: ey = (sa < sb) ? 8'd1 : 8'd0;
            endcase
        end
    endtask

    initial begin
        for (io = 0; io < 8; io = io + 1)
            for (ia = 0; ia < 256; ia = ia + 1)
                for (ib = 0; ib < 256; ib = ib + 1) begin
                    op = io; a = ia; b = ib; #1;
                    model;
                    if (y !== ey || zero !== (ey == 0) || carry !== ec || overflow !== eo) begin
                        if (errors < 20)
                            $display("FAIL: op=%0d a=%h b=%h got y=%h z=%b c=%b v=%b expected y=%h z=%b c=%b v=%b",
                                     op, a, b, y, zero, carry, overflow, ey, ey == 0, ec, eo);
                        errors = errors + 1;
                    end
                end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
