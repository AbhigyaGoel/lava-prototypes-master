`timescale 1ns/1ps
module tb;
    reg  [12:0] cw;
    wire [7:0]  data;
    wire        single_err, double_err;
    wire [3:0]  err_pos;
    integer errors = 0, n, j;

    reg  [3:0]  m_syn;
    reg         m_par, m_s, m_d;
    reg  [3:0]  m_pos;
    reg  [12:0] m_fixed;
    reg  [7:0]  m_data;

    hamming_secded dut (.cw(cw), .data(data), .single_err(single_err),
                        .double_err(double_err), .err_pos(err_pos));
    initial begin #1000000 $display("ERROR: watchdog timeout"); $finish; end

    // behavioral reference: syndrome = XOR of the indices of all set bits in positions 1..12
    task model;
        begin
            m_syn = 4'd0;
            for (j = 1; j <= 12; j = j + 1) if (cw[j]) m_syn = m_syn ^ j;
            m_par = ^cw;
            m_fixed = cw;
            if (m_par && m_syn <= 12) begin
                m_s = 1; m_d = 0; m_pos = m_syn;
                if (m_syn != 0) m_fixed[m_syn] = ~cw[m_syn];
            end else begin
                m_s = 0; m_d = (m_syn != 0); m_pos = 0;
            end
            m_data = {m_fixed[12], m_fixed[11], m_fixed[10], m_fixed[9],
                      m_fixed[7], m_fixed[6], m_fixed[5], m_fixed[3]};
        end
    endtask

    initial begin
        // exhaustive over all 2^13 received words
        for (n = 0; n < 8192; n = n + 1) begin
            cw = n; #1;
            model;
            if (data !== m_data || single_err !== m_s || double_err !== m_d || err_pos !== m_pos) begin
                if (errors < 20)
                    $display("FAIL: cw=%h syn=%0d par=%b data=%h s=%b d=%b pos=%0d expected data=%h s=%b d=%b pos=%0d",
                             cw, m_syn, m_par, data, single_err, double_err, err_pos,
                             m_data, m_s, m_d, m_pos);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
