`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg in_valid = 0, in_last = 0, out_ready = 0;
    reg [7:0] in_data = 0;
    wire in_ready, out_valid, out_last;
    wire [31:0] out_data;
    wire [3:0] out_keep;
    integer errors = 0, i, mode, bytes_in = 0, bytes_out = 0, words = 0;

    // reference model state
    reg [7:0]  m_b0, m_b1, m_b2;
    integer    m_cnt;
    reg        m_ov, m_ol, m_ready, acc, dlv;
    reg [31:0] m_od;
    reg [3:0]  m_ok;
    reg [7:0]  next_byte = 8'h01;

    width_packer dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
                      .in_data(in_data), .in_last(in_last), .out_valid(out_valid),
                      .out_ready(out_ready), .out_data(out_data), .out_keep(out_keep),
                      .out_last(out_last));
    always #5 clk = ~clk;
    initial begin #20000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_cnt = 0; m_ov = 0; m_ol = 0; m_od = 0; m_ok = 0; m_b0 = 0; m_b1 = 0; m_b2 = 0; end
    endtask

    task fail(input [8*40-1:0] msg);
        begin
            if (errors < 20)
                $display("FAIL: t=%0t %0s cnt=%0d in_v=%b in_r=%b last=%b out_v=%b out_r=%b d=%h k=%b l=%b | exp v=%b d=%h k=%b l=%b",
                         $time, msg, m_cnt, in_valid, in_ready, in_last, out_valid, out_ready, out_data,
                         out_keep, out_last, m_ov, m_od, m_ok, m_ol);
            errors = errors + 1;
        end
    endtask

    // model of one rising edge (handshakes evaluated on the values before the edge)
    task model_step;
        reg closes;
        begin
            closes = (m_cnt == 3) || in_last;
            if (acc) bytes_in = bytes_in + 1;
            if (dlv) begin
                words = words + 1;
                bytes_out = bytes_out + (m_ok[0] + m_ok[1] + m_ok[2] + m_ok[3]);
                m_ov = 0;
            end
            if (acc && closes) begin
                m_ov = 1; m_ol = in_last;
                case (m_cnt)
                    0: begin m_od = {24'd0, in_data};             m_ok = 4'b0001; end
                    1: begin m_od = {16'd0, in_data, m_b0};       m_ok = 4'b0011; end
                    2: begin m_od = {8'd0, in_data, m_b1, m_b0};  m_ok = 4'b0111; end
                    default: begin m_od = {in_data, m_b2, m_b1, m_b0}; m_ok = 4'b1111; end
                endcase
                m_cnt = 0;
            end else if (acc) begin
                case (m_cnt)
                    0: m_b0 = in_data;
                    1: m_b1 = in_data;
                    default: m_b2 = in_data;
                endcase
                m_cnt = m_cnt + 1;
            end
        end
    endtask

    task cycle(input iv, input il, input ordy);
        begin
            @(negedge clk);
            if (out_valid !== m_ov) fail("out_valid");
            else if (m_ov && (out_data !== m_od || out_keep !== m_ok || out_last !== m_ol)) fail("out word");
            in_valid = iv; in_last = il; out_ready = ordy;
            in_data = next_byte;
            #1;
            m_ready = !m_ov || out_ready || ((m_cnt != 3) && !in_last);
            if (in_ready !== m_ready) fail("in_ready");
            acc = in_valid && m_ready;
            dlv = m_ov && out_ready;
            @(posedge clk);
            model_step;
            if (acc) next_byte = next_byte * 8'd5 + 8'd3;
        end
    endtask

    initial begin
        model_reset;
        #1 rst_n = 0;
        #11 rst_n = 1;
        // directed: one-byte packets streaming, sink always ready (emit and drain together)
        for (i = 0; i < 20; i = i + 1) cycle(1, 1, 1);
        // directed: full word followed immediately by a short packet
        for (i = 0; i < 6; i = i + 1) cycle(1, i == 4, 1);
        for (i = 0; i < 4; i = i + 1) cycle(0, 0, 1);
        // directed: output stalled, then a last beat at every fill level
        for (mode = 0; mode < 4; mode = mode + 1) begin
            for (i = 0; i < 4; i = i + 1) cycle(1, 0, 0);      // word waiting in output register
            for (i = 0; i < mode; i = i + 1) cycle(1, 0, 0);   // partial fill
            for (i = 0; i < 3; i = i + 1) cycle(1, 1, 0);      // last offered while stalled
            for (i = 0; i < 3; i = i + 1) cycle(1, 1, 1);
            for (i = 0; i < 4; i = i + 1) cycle(0, 0, 1);
        end
        // random traffic with varying densities and packet lengths
        for (mode = 0; mode < 6; mode = mode + 1)
            for (i = 0; i < 4000; i = i + 1)
                case (mode)
                    0: cycle($random, $random, $random);
                    1: cycle(1, ($random % 8) == 0, ($random % 4) != 0);
                    2: cycle(1, ($random % 2) == 0, 1);
                    3: cycle(($random % 4) != 0, ($random % 3) == 0, ($random % 4) == 0);
                    4: cycle(1, ($random % 5) == 0, ($random % 2) == 0);
                    5: cycle(($random % 3) == 0, $random, ($random % 3) != 0);
                endcase
        // asynchronous reset with data held
        for (i = 0; i < 6; i = i + 1) cycle(1, 0, 0);
        @(negedge clk); in_valid = 0; #2 rst_n = 0; #1 model_reset;
        if (out_valid !== 1'b0) fail("reset out_valid");
        #1 rst_n = 1;
        @(posedge clk); acc = 0; dlv = 0; model_step;
        bytes_in = 0; bytes_out = 0;
        for (i = 0; i < 3000; i = i + 1) cycle($random, ($random % 4) == 0, $random);
        // flush: close any partial word and drain
        cycle(1, 1, 1);
        for (i = 0; i < 6; i = i + 1) cycle(0, 0, 1);
        if (bytes_in != bytes_out) begin
            $display("FAIL: bytes in %0d != bytes out %0d", bytes_in, bytes_out); errors = errors + 1;
        end
        if (words < 2000) begin $display("FAIL: only %0d words", words); errors = errors + 1; end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
