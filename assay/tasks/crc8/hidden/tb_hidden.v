`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, clear = 0, valid = 0;
    reg [7:0] data = 0;
    wire [7:0] crc;
    integer errors = 0, i, j;
    reg [7:0] ref_crc, x;

    crc8 dut (.clk(clk), .rst_n(rst_n), .clear(clear), .valid(valid), .data(data), .crc(crc));
    always #5 clk = ~clk;
    initial begin #1000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (crc !== ref_crc) begin
            $display("FAIL: t=%0t clear=%b valid=%b data=%h crc=%h expected=%h",
                     $time, clear, valid, data, crc, ref_crc);
            errors = errors + 1;
        end
    endtask

    // apply current inputs for one rising edge and update the reference model
    task step;
        begin
            @(posedge clk); #1;
            if (clear) ref_crc = 8'h00;
            else if (valid) begin
                x = ref_crc ^ data;
                for (j = 0; j < 8; j = j + 1) x = x[7] ? ((x << 1) ^ 8'h07) : (x << 1);
                ref_crc = x;
            end
            check;
        end
    endtask

    initial begin
        ref_crc = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        // check value
        for (i = 0; i < 9; i = i + 1) begin valid = 1; data = 8'h31 + i; step; end
        valid = 0;
        if (crc !== 8'hF4) begin $display("FAIL: check value %h != F4", crc); errors = errors + 1; end
        // directed: clear and valid together discards the byte
        clear = 1; valid = 1; data = 8'hA5; step;
        clear = 0; valid = 1; data = 8'h5A; step;
        clear = 1; valid = 1; data = 8'hFF; step;
        clear = 0; valid = 0; step;
        // every single byte from zero state
        for (i = 0; i < 256; i = i + 1) begin
            clear = 1; valid = 0; step;
            clear = 0; valid = 1; data = i; step;
        end
        // long random stream
        for (i = 0; i < 3000; i = i + 1) begin
            clear = (($random & 15) == 0);
            valid = $random;
            data  = $random;
            step;
        end
        // async reset mid-stream
        clear = 0; valid = 1; data = 8'h3C;
        @(negedge clk); rst_n = 0; #1 ref_crc = 0; check;
        #3 rst_n = 1;
        for (i = 0; i < 50; i = i + 1) begin
            clear = 0; valid = $random; data = $random; step;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
