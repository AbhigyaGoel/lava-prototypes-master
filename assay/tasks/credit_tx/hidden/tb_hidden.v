`timescale 1ns/1ps
module tb;
    reg        clk = 0, rst_n = 1;
    reg        in_valid = 0, credit_return = 0;
    reg  [7:0] in_data = 0;
    reg  [1:0] credit_count = 0;
    wire       in_ready, tx_valid, can_send, credit_err;
    wire [7:0] tx_data;
    wire [2:0] credits;
    wire [15:0] beats_sent;
    integer errors = 0, i, mode, vd, rd;

    localparam integer N = 7;

    // reference model
    integer    m_cred, m_sum, m_ret;
    reg        m_err, m_txv, e_send;
    reg  [7:0] m_txd;
    reg [15:0] m_beats;

    credit_tx dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data), .in_ready(in_ready),
                   .tx_valid(tx_valid), .tx_data(tx_data), .credit_return(credit_return),
                   .credit_count(credit_count), .can_send(can_send), .credits(credits),
                   .credit_err(credit_err), .beats_sent(beats_sent));
    always #5 clk = ~clk;
    initial begin #50000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_cred = N; m_err = 0; m_txv = 0; m_txd = 0; m_beats = 0; end
    endtask

    task check;
        begin
            e_send = in_valid && (m_cred != 0);
            if (credits !== m_cred[2:0] || can_send !== (m_cred != 0) || in_ready !== (m_cred != 0) ||
                credit_err !== m_err || tx_valid !== m_txv || tx_data !== m_txd ||
                beats_sent !== m_beats) begin
                if (errors < 25)
                    $display("FAIL: t=%0t in_v=%b ret=%b cnt=%0d | credits=%0d/%0d can_send=%b err=%b/%b tx_valid=%b/%b tx_data=%h/%h beats=%0d/%0d (got/exp)",
                             $time, in_valid, credit_return, credit_count, credits, m_cred, can_send,
                             credit_err, m_err, tx_valid, m_txv, tx_data, m_txd, beats_sent, m_beats);
                errors = errors + 1;
            end
        end
    endtask

    // drive at negedge, check, update the model at posedge
    task cycle(input v, input r, input [1:0] c);
        begin
            @(negedge clk);
            in_valid = v; credit_return = r; credit_count = c; in_data = $random;
            #1 check;
            @(posedge clk);
            m_ret = r ? c : 0;
            m_sum = m_cred - e_send + m_ret;
            if (m_sum > N) begin m_cred = N; m_err = 1; end
            else m_cred = m_sum;
            m_txv = e_send;
            if (e_send) begin m_txd = in_data; m_beats = m_beats + 1; end
        end
    endtask

    // a well-behaved receiver: never returns more than is outstanding (N - credits after send)
    task legal_cycle(input integer vdens, input integer rdens);
        reg v;
        integer outst, c;
        begin
            v = ({$random} % 16) < vdens;
            outst = N - m_cred + ((v && m_cred != 0) ? 1 : 0);
            c = 1 + {$random} % 3;
            if (c > outst) c = outst;
            if (c > 0 && ({$random} % 16) < rdens) cycle(v, 1, c);
            else cycle(v, ({$random} % 8) == 0, 0);
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); #2 rst_n = 0; #1 model_reset; #1 check;
            #2 rst_n = 1;
        end
    endtask

    initial begin
        model_reset;
        #1 rst_n = 0;
        #2 check;
        @(negedge clk); rst_n = 1;

        // directed: send and return in the same cycle
        cycle(1, 0, 0); cycle(1, 0, 0); cycle(1, 0, 0);       // 4 left
        cycle(1, 1, 1); cycle(1, 1, 2); cycle(1, 1, 3);       // 4, 5, 7
        cycle(1, 1, 1);                                       // 7 (send+1 at max)
        for (i = 0; i < 7; i = i + 1) cycle(1, 0, 0);         // 0
        cycle(1, 1, 3);                                       // no send at 0 credits, +3
        cycle(1, 1, 0);                                       // count 0 returns nothing
        cycle(0, 0, 0);
        // directed: over-return at various levels, flag must stay set
        cycle(0, 1, 3); cycle(0, 1, 3); cycle(0, 1, 3);       // 3 -> 6 -> 9>7: err
        cycle(1, 0, 0); cycle(1, 0, 0); cycle(0, 1, 2);       // valid return after error
        for (i = 0; i < 5; i = i + 1) cycle(0, 0, 0);
        do_reset;
        cycle(1, 0, 0); cycle(0, 1, 2);                       // 6 + 2 = 8 > 7
        cycle(0, 0, 0);
        do_reset;
        cycle(1, 0, 0); cycle(1, 0, 0); cycle(1, 1, 3);       // 5 - 1 + 3 = 7 ok
        cycle(0, 1, 1);                                       // 8 > 7: err
        do_reset;

        // random, protocol-compliant receiver (credit_err must stay 0)
        for (mode = 0; mode < 9; mode = mode + 1) begin
            vd = (mode % 3 == 0) ? 4 : (mode % 3 == 1) ? 12 : 16;
            rd = (mode / 3 == 0) ? 3 : (mode / 3 == 1) ? 8 : 14;
            for (i = 0; i < 800; i = i + 1) legal_cycle(vd, rd);
        end

        // random, misbehaving receiver (arbitrary returns), with periodic resets
        for (mode = 0; mode < 8; mode = mode + 1) begin
            for (i = 0; i < 400; i = i + 1)
                if (i < 300) legal_cycle(10, 6);
                else cycle($random, ({$random} % 4) == 0, $random);
            for (i = 0; i < 200; i = i + 1) legal_cycle(8, 8);
            do_reset;
        end

        for (i = 0; i < 1000; i = i + 1) cycle($random, $random, $random);

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
