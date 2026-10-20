`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg in_valid = 0, out_ready = 0;
    reg [7:0] in_data = 0;
    wire in_ready, out_valid;
    wire [7:0] out_data;
    integer errors = 0, i, mode;

    // scoreboard queue
    reg [7:0] q [0:255];
    integer head = 0, tail = 0, occ = 0;
    reg [7:0] next_word = 0;
    reg acc, dlv;

    pipe_stage dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
                    .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready),
                    .out_data(out_data));
    always #5 clk = ~clk;
    initial begin #2000000 $display("ERROR: watchdog timeout"); $finish; end

    task fail(input [8*48-1:0] msg);
        begin
            if (errors < 20)
                $display("FAIL: t=%0t %0s occ=%0d in_v=%b in_r=%b out_v=%b out_r=%b out_d=%h exp_d=%h",
                         $time, msg, occ, in_valid, in_ready, out_valid, out_ready, out_data, q[head[7:0]]);
            errors = errors + 1;
        end
    endtask

    // drive at negedge (after checking registered outputs), sample handshakes at posedge
    task cycle(input iv, input ordy);
        begin
            @(negedge clk);
            if (out_valid !== (occ > 0)) fail("out_valid");
            if (out_valid === 1'b1 && occ > 0 && out_data !== q[head[7:0]]) fail("out_data");
            in_valid = iv; out_ready = ordy;
            if (iv) in_data = next_word;
            #1;
            if (in_ready !== (occ < 2)) fail("in_ready");
            acc = in_valid && in_ready;
            dlv = out_valid && out_ready;
            @(posedge clk);
            if (acc) begin
                q[tail[7:0]] = in_data; tail = tail + 1; occ = occ + 1;
                next_word = next_word + 8'd37;
            end
            if (dlv) begin head = head + 1; occ = occ - 1; end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        // directed: fill both entries under stall, then drain while pushing
        cycle(1, 0); cycle(1, 0); cycle(1, 0); cycle(1, 0);
        cycle(1, 1); cycle(1, 1); cycle(1, 0); cycle(1, 1); cycle(0, 1); cycle(0, 1); cycle(0, 1);
        // directed: full + sink ready + source valid (combinational-ready hazard)
        cycle(1, 0); cycle(1, 0); cycle(1, 1); cycle(1, 1); cycle(1, 1); cycle(0, 1); cycle(0, 1);
        // random back-pressure with varying densities
        for (mode = 0; mode < 4; mode = mode + 1)
            for (i = 0; i < 1500; i = i + 1)
                case (mode)
                    0: cycle($random, $random);
                    1: cycle(1, ($random % 4) == 0);
                    2: cycle(($random % 4) == 0, 1);
                    3: cycle(($random % 3) != 0, ($random % 3) != 0);
                endcase
        // async reset while full
        cycle(1, 0); cycle(1, 0); cycle(1, 0);
        @(negedge clk); in_valid = 0; #2 rst_n = 0; #1;
        head = 0; tail = 0; occ = 0;
        if (out_valid !== 1'b0 || in_ready !== 1'b1) begin
            $display("FAIL: not empty during reset"); errors = errors + 1;
        end
        #1 rst_n = 1;
        for (i = 0; i < 500; i = i + 1) cycle($random, $random);
        for (i = 0; i < 4; i = i + 1) cycle(0, 1);
        if (occ != 0) begin $display("FAIL: words lost or stuck, occ=%0d", occ); errors = errors + 1; end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
