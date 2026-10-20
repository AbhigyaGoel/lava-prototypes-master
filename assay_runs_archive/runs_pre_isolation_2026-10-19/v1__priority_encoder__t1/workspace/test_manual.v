`timescale 1ns/1ps
module test;
    reg  [7:0] in;
    wire [2:0] y;
    wire valid;
    
    priority_encoder dut (.in(in), .y(y), .valid(valid));
    
    initial begin
        // Test case: only bit 3 set (should give y=3)
        in = 8'b00001000;
        #1;
        $display("in=00001000 (8): y=%d (expected 3), valid=%b", y, valid);
        
        $finish;
    end
endmodule
