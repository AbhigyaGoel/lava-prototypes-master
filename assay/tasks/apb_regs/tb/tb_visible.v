`timescale 1ns/1ps
module tb;
    reg        pclk = 0, presetn = 1;
    reg        psel = 0, penable = 0, pwrite = 0;
    reg  [7:0] paddr = 0;
    reg [31:0] pwdata = 0;
    reg  [3:0] hw_status = 0, hw_event = 0;
    wire [31:0] prdata;
    wire       pready, pslverr, irq;
    wire [7:0] ctrl_out;
    integer errors = 0;
    reg [31:0] rd;
    reg        err;

    apb_regs dut (.pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable), .pwrite(pwrite),
                  .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
                  .hw_status(hw_status), .hw_event(hw_event), .ctrl_out(ctrl_out), .irq(irq));
    always #5 pclk = ~pclk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task apb_write(input [7:0] a, input [31:0] d);
        begin
            @(negedge pclk); psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d;
            @(negedge pclk); penable = 1; #1 err = pslverr;
            @(negedge pclk); psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    task apb_read(input [7:0] a);
        begin
            @(negedge pclk); psel = 1; penable = 0; pwrite = 0; paddr = a;
            @(negedge pclk); penable = 1; #1 rd = prdata; err = pslverr;
            @(negedge pclk); psel = 0; penable = 0;
        end
    endtask

    task expect_rd(input [7:0] a, input [31:0] exp);
        begin
            apb_read(a);
            if (rd !== exp || err !== 1'b0) begin
                $display("FAIL: read 0x%h = %h (pslverr=%b), expected %h", a, rd, err, exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1 presetn = 0;
        #11 presetn = 1;
        if (pready !== 1'b1) begin $display("FAIL: pready not 1"); errors = errors + 1; end
        expect_rd(8'h00, 32'h10);
        expect_rd(8'h08, 32'h0);
        expect_rd(8'h0C, 32'h0);
        // CTRL read/write
        apb_write(8'h00, 32'hA5);
        expect_rd(8'h00, 32'hA5);
        if (ctrl_out !== 8'hA5) begin $display("FAIL: ctrl_out=%h", ctrl_out); errors = errors + 1; end
        // STATUS reflects hw_status and EN
        hw_status = 4'h6;
        expect_rd(8'h04, 32'h16);
        // enable all interrupts, raise event 2
        apb_write(8'h0C, 32'hF);
        expect_rd(8'h0C, 32'hF);
        @(negedge pclk); hw_event = 4'b0100;
        @(negedge pclk); hw_event = 4'b0000;
        if (irq !== 1'b1) begin $display("FAIL: irq not raised"); errors = errors + 1; end
        expect_rd(8'h08, 32'h4);
        expect_rd(8'h04, 32'h36);
        // clear it
        apb_write(8'h08, 32'h4);
        expect_rd(8'h08, 32'h0);
        if (irq !== 1'b0) begin $display("FAIL: irq not cleared"); errors = errors + 1; end
        // unmapped address
        apb_read(8'h40);
        if (err !== 1'b1 || rd !== 32'h0) begin
            $display("FAIL: unmapped read pslverr=%b prdata=%h", err, rd); errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
