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
    integer errors = 0, i, n, idle;

    // reference model state
    reg [7:0] m_ctrl;
    reg [3:0] m_ists, m_ien;
    reg [31:0] e_prdata;
    reg        e_pslverr, e_irq, e_mapped;
    reg [3:0]  clr;

    apb_regs dut (.pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable), .pwrite(pwrite),
                  .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
                  .hw_status(hw_status), .hw_event(hw_event), .ctrl_out(ctrl_out), .irq(irq));
    always #5 pclk = ~pclk;
    initial begin #20000000 $display("ERROR: watchdog timeout"); $finish; end

    task model_reset;
        begin m_ctrl = 8'h10; m_ists = 4'h0; m_ien = 4'h0; end
    endtask

    task compute;
        begin
            e_irq = |(m_ists & m_ien);
            e_mapped = (paddr == 8'h00) || (paddr == 8'h04) || (paddr == 8'h08) || (paddr == 8'h0C);
            e_pslverr = psel && penable && !e_mapped;
            e_prdata = 32'h0;
            if (psel && penable && !pwrite)
                case (paddr)
                    8'h00: e_prdata = {24'h0, m_ctrl};
                    8'h04: e_prdata = {26'h0, e_irq, m_ctrl[0], hw_status};
                    8'h08: e_prdata = {28'h0, m_ists};
                    8'h0C: e_prdata = {28'h0, m_ien};
                    default: e_prdata = 32'h0;
                endcase
        end
    endtask

    task check;
        begin
            compute;
            if (prdata !== e_prdata || pslverr !== e_pslverr || irq !== e_irq ||
                pready !== 1'b1 || ctrl_out !== m_ctrl) begin
                if (errors < 25)
                    $display("FAIL: t=%0t sel=%b en=%b wr=%b addr=%h | prdata=%h/%h pslverr=%b/%b irq=%b/%b ctrl_out=%h/%h (got/exp) ists=%h ien=%h",
                             $time, psel, penable, pwrite, paddr, prdata, e_prdata, pslverr, e_pslverr,
                             irq, e_irq, ctrl_out, m_ctrl, m_ists, m_ien);
                errors = errors + 1;
            end
        end
    endtask

    // drive at negedge, check combinational outputs, update model at posedge
    task cycle(input s, input en, input w, input [7:0] a, input [31:0] d, input [3:0] ev);
        begin
            @(negedge pclk);
            psel = s; penable = en; pwrite = w; paddr = a; pwdata = d; hw_event = ev;
            #1 check;
            @(posedge pclk);
            clr = (s && en && w && a == 8'h08) ? d[3:0] : 4'h0;
            if (s && en && w && a == 8'h00) m_ctrl = {d[7:4], 1'b0, d[2:0]};
            if (s && en && w && a == 8'h0C) m_ien = d[3:0];
            m_ists = (m_ists & ~clr) | ev;
        end
    endtask

    task xfer(input w, input [7:0] a, input [31:0] d, input [3:0] ev0, input [3:0] ev1);
        begin
            cycle(1, 0, w, a, d, ev0);
            cycle(1, 1, w, a, d, ev1);
        end
    endtask

    function [7:0] rand_addr(input integer r);
        begin
            case (r % 10)
                0, 1: rand_addr = 8'h00;
                2:    rand_addr = 8'h04;
                3, 4: rand_addr = 8'h08;
                5, 6: rand_addr = 8'h0C;
                7:    rand_addr = {$random} % 16;          // includes unaligned 0x01-0x0F
                8:    rand_addr = 8'h10 + ({$random} % 4) * 4;
                default: rand_addr = $random;
            endcase
        end
    endfunction

    function [3:0] rand_ev(input integer dens);
        integer b;
        begin
            rand_ev = 4'h0;
            for (b = 0; b < 4; b = b + 1)
                if (({$random} % 16) < dens) rand_ev[b] = 1'b1;
        end
    endfunction

    initial begin
        model_reset;
        #1 presetn = 0;
        #2 check;
        #9 presetn = 1;

        // directed: reserved CTRL bit
        xfer(1, 8'h00, 32'hFFFF_FFFF, 0, 0);
        xfer(0, 8'h00, 0, 0, 0);
        xfer(1, 8'h00, 32'h0000_0008, 0, 0);
        xfer(0, 8'h00, 0, 0, 0);
        // directed: pending but disabled interrupt must not show in irq / STATUS[5]
        xfer(1, 8'h0C, 32'h0, 0, 0);
        cycle(0, 0, 0, 8'h00, 0, 4'b0011);
        xfer(0, 8'h04, 0, 0, 0);
        xfer(0, 8'h08, 0, 0, 0);
        xfer(1, 8'h0C, 32'h2, 0, 0);
        xfer(0, 8'h04, 0, 0, 0);
        // directed: same-cycle hardware set and software clear (set wins)
        xfer(1, 8'h08, 32'hF, 0, 4'b0010);
        xfer(0, 8'h08, 0, 0, 0);
        xfer(0, 8'h04, 0, 0, 0);
        xfer(1, 8'h08, 32'hF, 4'b0001, 4'b1000);
        xfer(0, 8'h08, 0, 0, 0);
        // directed: writes to STATUS and unmapped/unaligned addresses are ignored
        xfer(1, 8'h04, 32'hFFFF_FFFF, 0, 0);
        xfer(1, 8'h01, 32'hFFFF_FFFF, 0, 0);
        xfer(1, 8'h0D, 32'hFFFF_FFFF, 0, 0);
        xfer(1, 8'h80, 32'hFFFF_FFFF, 0, 0);
        xfer(0, 8'h00, 0, 0, 0);
        xfer(0, 8'h0C, 0, 0, 0);
        xfer(0, 8'h09, 0, 0, 0);

        // random transfers with random idle gaps and random hardware events
        for (i = 0; i < 6000; i = i + 1) begin
            n = (i < 3000) ? 4 : 1;   // event density (out of 16)
            idle = {$random} % 3;
            while (idle > 0) begin
                cycle(0, $random, $random, $random, $random, rand_ev(n));
                idle = idle - 1;
            end
            hw_status = $random;
            xfer($random, rand_addr($random), $random, rand_ev(n), rand_ev(n));
        end

        // async reset in the middle of an access phase
        cycle(1, 0, 1, 8'h00, 32'h77, 4'hF);
        @(negedge pclk); penable = 1; #2 presetn = 0; #1 model_reset;
        psel = 0; penable = 0; hw_event = 0; #1 check;
        #2 presetn = 1;
        for (i = 0; i < 500; i = i + 1)
            xfer($random, rand_addr($random), $random, rand_ev(3), rand_ev(3));

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
