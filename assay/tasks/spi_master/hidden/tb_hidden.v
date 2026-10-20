`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0, cpol = 0, cpha = 0, miso = 0;
    reg [3:0] div = 0;
    reg [7:0] tx_data = 0;
    wire sclk, mosi, cs_n, busy, done;
    wire [7:0] rx_data;
    integer errors = 0, i, n, mode, xfers = 0;

    // behavioral reference model
    reg       m_busy, m_cs_n, m_sclk, m_done;
    reg [7:0] m_rx_data, m_tx_byte, m_rx_acc;
    reg       m_cpol, m_cpha;
    reg [3:0] m_div;
    integer   m_clk_in_hp, m_edges, m_shifts;
    reg       m_mosi, rise, smp;

    spi_master dut (.clk(clk), .rst_n(rst_n), .start(start), .cpol(cpol), .cpha(cpha), .div(div),
                    .tx_data(tx_data), .miso(miso), .sclk(sclk), .mosi(mosi), .cs_n(cs_n),
                    .busy(busy), .done(done), .rx_data(rx_data));
    always #5 clk = ~clk;
    initial begin #20000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin
            m_busy = 0; m_cs_n = 1; m_sclk = 0; m_done = 0; m_rx_data = 0; m_tx_byte = 0;
            m_rx_acc = 0; m_cpol = 0; m_cpha = 0; m_div = 0; m_clk_in_hp = 0; m_edges = 0; m_shifts = 0;
        end
    endtask

    // advance the model by one rising clock edge (inputs are stable since the previous negedge)
    task model_step;
        begin
            m_done = 0;
            if (!m_busy) begin
                m_cpol = cpol; m_cpha = cpha; m_div = div; m_sclk = cpol;
                if (start) begin
                    m_busy = 1; m_cs_n = 0; m_tx_byte = tx_data;
                    m_clk_in_hp = 0; m_edges = 0; m_shifts = 0;
                end
            end else begin
                m_clk_in_hp = m_clk_in_hp + 1;
                if (m_clk_in_hp == m_div + 1) begin
                    m_clk_in_hp = 0;
                    if (m_edges == 16) begin
                        m_busy = 0; m_cs_n = 1; m_done = 1; m_rx_data = m_rx_acc; xfers = xfers + 1;
                    end else begin
                        rise = (m_sclk == 1'b0);
                        smp  = (rise == (m_cpol == m_cpha));
                        if (smp) m_rx_acc = {m_rx_acc[6:0], miso};
                        else if (m_edges > 0) m_shifts = m_shifts + 1;
                        m_sclk = ~m_sclk;
                        m_edges = m_edges + 1;
                    end
                end
            end
        end
    endtask

    task check;
        begin
            m_mosi = m_cs_n ? 1'b0 : (m_shifts >= 8 ? 1'b0 : m_tx_byte[7 - m_shifts]);
            if (sclk !== m_sclk || mosi !== m_mosi || cs_n !== m_cs_n || busy !== m_busy ||
                done !== m_done || rx_data !== m_rx_data) begin
                if (errors < 20)
                    $display("FAIL: t=%0t mode=%0d div=%0d edges=%0d dut sclk=%b mosi=%b cs_n=%b busy=%b done=%b rx=%h | exp %b %b %b %b %b %h",
                             $time, {m_cpol, m_cpha}, m_div, m_edges, sclk, mosi, cs_n, busy, done, rx_data,
                             m_sclk, m_mosi, m_cs_n, m_busy, m_done, m_rx_data);
                errors = errors + 1;
            end
        end
    endtask

    // one clock: check at negedge, drive, then advance model at posedge
    task cycle(input s, input p, input h, input [3:0] d, input [7:0] t, input mi);
        begin
            @(negedge clk);
            check;
            start = s; cpol = p; cpha = h; div = d; tx_data = t; miso = mi;
            @(posedge clk);
            model_step;
        end
    endtask

    task run_xfer(input p, input h, input [3:0] d, input [7:0] t);
        begin
            cycle(1, p, h, d, t, $random);
            n = 0;
            while (m_busy && n < 400) begin
                cycle($random, p, h, d, $random, $random);
                n = n + 1;
            end
            cycle(0, p, h, d, t, $random);
            cycle(0, p, h, d, t, $random);
        end
    endtask

    reg [3:0] rd;
    initial begin
        model_reset;
        #1 rst_n = 0;
        #11 rst_n = 1;
        // directed: every mode, several dividers, fixed config
        for (mode = 0; mode < 4; mode = mode + 1)
            for (i = 0; i < 3; i = i + 1)
                run_xfer(mode[1], mode[0], i, 8'hA5 ^ (mode * 37) ^ i);
        // directed: start held high -> back-to-back transfers, restart in the done cycle
        for (mode = 0; mode < 4; mode = mode + 1)
            for (i = 0; i < 60; i = i + 1)
                cycle(1, mode[1], mode[0], 4'd0, $random, $random);
        // directed: configuration inputs wiggle during a transfer (must be ignored)
        for (mode = 0; mode < 4; mode = mode + 1) begin
            cycle(1, mode[1], mode[0], 4'd1, 8'h3C, $random);
            for (i = 0; i < 50; i = i + 1)
                cycle(0, $random, $random, $random, $random, $random);
        end
        // long random: config changes occasionally, including mid-transfer
        rd = 0;
        for (i = 0; i < 40000; i = i + 1) begin
            if (($random % 8) == 0) rd = (($random % 4) == 0) ? $random : ($random & 3);
            cycle(($random % 6) == 0,
                  (($random % 8) == 0) ? ~cpol : cpol,
                  (($random % 8) == 0) ? ~cpha : cpha,
                  rd, $random, $random);
        end
        // asynchronous reset in the middle of a transfer
        cycle(1, 1'b1, 1'b1, 4'd2, 8'hC3, 1'b1);
        for (i = 0; i < 20; i = i + 1) cycle(0, 1'b1, 1'b1, 4'd2, 8'hC3, $random);
        @(negedge clk); start = 0; #2 rst_n = 0; #1 model_reset; check; #1 rst_n = 1;
        @(posedge clk); model_step;
        for (i = 0; i < 3000; i = i + 1)
            cycle(($random % 5) == 0, $random, $random, $random & 3, $random, $random);
        for (i = 0; i < 600; i = i + 1) cycle(0, 0, 0, 0, 0, 0);
        if (xfers < 300) begin $display("FAIL: only %0d transfers completed", xfers); errors = errors + 1; end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
