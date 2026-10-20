`timescale 1ns/1ps
module tb;
    reg clk = 0, rst_n = 1;
    reg start = 0, cpol = 0, cpha = 0;
    reg [3:0] div = 0;
    reg [7:0] tx_data = 0;
    wire sclk, mosi, cs_n, busy, done, miso;
    wire [7:0] rx_data;
    integer errors = 0, i, edges, cycles;
    reg prev_sclk;

    assign miso = mosi;   // loopback
    spi_master dut (.clk(clk), .rst_n(rst_n), .start(start), .cpol(cpol), .cpha(cpha), .div(div),
                    .tx_data(tx_data), .miso(miso), .sclk(sclk), .mosi(mosi), .cs_n(cs_n),
                    .busy(busy), .done(done), .rx_data(rx_data));
    always #5 clk = ~clk;
    initial begin #200000 $display("ERROR: watchdog timeout"); $finish; end

    task xfer(input p, input h, input [3:0] d, input [7:0] t);
        begin
            @(negedge clk); cpol = p; cpha = h; div = d;
            @(negedge clk); @(negedge clk);
            if (sclk !== p || cs_n !== 1'b1 || busy !== 1'b0) begin
                $display("FAIL: bad idle state for mode %0d", {p, h}); errors = errors + 1;
            end
            start = 1; tx_data = t;
            @(negedge clk); start = 0; tx_data = 8'h00;
            if (cs_n !== 1'b0 || busy !== 1'b1) begin
                $display("FAIL: transfer did not start (mode %0d)", {p, h}); errors = errors + 1;
            end
            edges = 0; cycles = 0; prev_sclk = sclk;
            while (done !== 1'b1 && cycles < 1000) begin
                @(negedge clk); cycles = cycles + 1;
                if (sclk !== prev_sclk) edges = edges + 1;
                prev_sclk = sclk;
            end
            if (done !== 1'b1) begin $display("FAIL: no done (mode %0d)", {p, h}); errors = errors + 1; end
            if (edges != 16) begin $display("FAIL: %0d sclk edges, expected 16", edges); errors = errors + 1; end
            if (rx_data !== t) begin
                $display("FAIL: mode %0d div %0d rx_data=%h expected %h", {p, h}, d, rx_data, t);
                errors = errors + 1;
            end
            if (cs_n !== 1'b1 || busy !== 1'b0 || sclk !== p) begin
                $display("FAIL: bad state after transfer (mode %0d)", {p, h}); errors = errors + 1;
            end
            @(negedge clk);
            if (done !== 1'b0) begin $display("FAIL: done longer than one cycle"); errors = errors + 1; end
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #11 rst_n = 1;
        xfer(0, 0, 4'd1, 8'hA5);
        xfer(0, 0, 4'd3, 8'h3C);
        xfer(0, 1, 4'd1, 8'h96);
        xfer(1, 0, 4'd2, 8'hF0);
        xfer(0, 0, 4'd0, 8'h01);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
