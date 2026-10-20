`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, en = 0;
    wire [3:0] gray;
    integer errors = 0, i;
    reg [3:0] bin_ref;

    gray_counter dut (.clk(clk), .rst_n(rst_n), .en(en), .gray(gray));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (gray !== (bin_ref ^ (bin_ref >> 1))) begin
            $display("FAIL: t=%0t en=%b gray=%b expected=%b", $time, en, gray, bin_ref ^ (bin_ref >> 1));
            errors = errors + 1;
        end
    endtask

    initial begin
        bin_ref = 0;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        for (i = 0; i < 200; i = i + 1) begin
            en = $random;
            @(posedge clk); #1;
            if (en) bin_ref = bin_ref + 1;
            check;
        end
        // async reset mid-count
        #2 rst_n = 0; #1 bin_ref = 0; check;
        #5 rst_n = 1;
        en = 1;
        for (i = 0; i < 40; i = i + 1) begin
            @(posedge clk); #1; bin_ref = bin_ref + 1; check;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
