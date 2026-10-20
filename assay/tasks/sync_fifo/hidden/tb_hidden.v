`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1, wr_en = 0, rd_en = 0;
    reg [7:0] din = 0;
    wire [7:0] dout;
    wire full, empty;
    wire [3:0] count;
    integer errors = 0, i;

    // reference model
    reg [7:0] q [0:7];
    integer head, n;
    reg [7:0] ref_dout;
    reg wok, rok;

    sync_fifo dut (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din), .rd_en(rd_en),
                   .dout(dout), .full(full), .empty(empty), .count(count));
    always #5 clk = ~clk;
    initial begin #2000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        if (count !== n || full !== (n == 8) || empty !== (n == 0) || dout !== ref_dout) begin
            $display("FAIL: t=%0t wr=%b rd=%b count=%0d full=%b empty=%b dout=%h expected count=%0d dout=%h",
                     $time, wr_en, rd_en, count, full, empty, dout, n, ref_dout);
            errors = errors + 1;
        end
    endtask

    // inputs are set before calling; one rising edge, update model, check
    task step;
        begin
            wok = wr_en && (n < 8);
            rok = rd_en && (n > 0);
            @(posedge clk); #1;
            if (rok) begin ref_dout = q[head]; head = (head + 1) % 8; end
            if (wok) q[(head + n - (rok ? 1 : 0)) % 8] = din;
            n = n + (wok ? 1 : 0) - (rok ? 1 : 0);
            check;
        end
    endtask

    task reset_model;
        begin head = 0; n = 0; ref_dout = 0; end
    endtask

    initial begin
        reset_model;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        // underflow: read while empty
        rd_en = 1; wr_en = 0; step; step;
        // empty + simultaneous: only the write happens
        rd_en = 1; wr_en = 1; din = 8'h11; step;
        // simultaneous with 0<count<8
        rd_en = 1; wr_en = 1; din = 8'h22; step;
        rd_en = 1; wr_en = 1; din = 8'h33; step;
        rd_en = 0; wr_en = 1; din = 8'h44; step;
        rd_en = 1; wr_en = 1; din = 8'h55; step;
        // fill to full, then overflow attempts
        rd_en = 0; wr_en = 1;
        for (i = 0; i < 10; i = i + 1) begin din = 8'h60 + i; step; end
        // full + simultaneous: only the read happens
        rd_en = 1; wr_en = 1; din = 8'hEE; step;
        rd_en = 1; wr_en = 1; din = 8'hEF; step;
        // drain past empty
        rd_en = 1; wr_en = 0;
        for (i = 0; i < 10; i = i + 1) step;
        // long random, with varying write/read bias
        for (i = 0; i < 6000; i = i + 1) begin
            case ((i / 500) % 3)
                0: begin wr_en = ($random % 4) != 0; rd_en = ($random % 4) == 0; end
                1: begin wr_en = ($random % 4) == 0; rd_en = ($random % 4) != 0; end
                default: begin wr_en = $random; rd_en = $random; end
            endcase
            din = $random;
            step;
        end
        // async reset mid-operation
        wr_en = 1; rd_en = 0; din = 8'h77; step; step; step;
        @(negedge clk); wr_en = 0; rd_en = 0; rst_n = 0; #1 reset_model; check; #3 rst_n = 1;
        for (i = 0; i < 300; i = i + 1) begin
            wr_en = $random; rd_en = $random; din = $random; step;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
