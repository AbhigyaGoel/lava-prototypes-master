`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg [3:0] req = 0;
    wire [3:0] grant;
    integer errors = 0, i, k, p;
    reg [1:0] ref_ptr;
    reg [3:0] exp_grant;
    reg [1:0] exp_idx;

    rr_arbiter dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
    always #5 clk = ~clk;
    initial begin #1000000 $display("ERROR: watchdog timeout"); $finish; end

    task compute;
        begin
            exp_grant = 4'b0000; exp_idx = ref_ptr;
            for (k = 3; k >= 0; k = k - 1) begin
                p = (ref_ptr + k) % 4;
                if (req[p]) begin exp_grant = 4'b0001 << p; exp_idx = p; end
            end
        end
    endtask

    // drive req at negedge, check grant, update reference pointer at posedge
    task cycle(input [3:0] r);
        begin
            @(negedge clk); req = r; #1;
            compute;
            if (grant !== exp_grant) begin
                $display("FAIL: t=%0t ptr_ref=%0d req=%b grant=%b expected=%b",
                         $time, ref_ptr, req, grant, exp_grant);
                errors = errors + 1;
            end
            @(posedge clk);
            if (req != 0) ref_ptr = exp_idx + 1;
        end
    endtask

    initial begin
        ref_ptr = 0;
        #1 rst_n = 0;
        #11 rst_n = 1;
        // every request pattern from every pointer value
        for (i = 0; i < 64; i = i + 1) begin
            cycle(4'b0001 << ((i + 3) % 4));   // grant requester ptr-1 -> pointer = i % 4
            cycle(i / 4);                       // pattern under test
        end
        // rotation with all requesting, and idle cycles holding the pointer
        for (i = 0; i < 12; i = i + 1) cycle(4'b1111);
        cycle(4'b0010); cycle(4'b0000); cycle(4'b0000); cycle(4'b0011); cycle(4'b0011); cycle(4'b0011);
        // long random
        for (i = 0; i < 4000; i = i + 1) cycle($random);
        // async reset mid-run
        cycle(4'b0100);
        @(negedge clk); req = 4'b0000; rst_n = 0; #1 ref_ptr = 0; #3 rst_n = 1;
        for (i = 0; i < 100; i = i + 1) cycle($random);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
