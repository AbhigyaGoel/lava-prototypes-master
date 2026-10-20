`timescale 1ns/1ps
module tb;
    localparam MGT = 8, MGMIN = 3, MYT = 2, SGT = 4, SYT = 3;
    localparam RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;
    reg clk = 0, rst_n = 1, ped_req = 0;
    wire [2:0] main_light, side_light;
    wire walk;
    integer errors = 0, i, j;

    // reference model
    integer r_state, r_timer, r_next;
    reg     r_pend;
    reg [2:0] e_main, e_side;
    reg       e_walk;

    traffic_light dut (.clk(clk), .rst_n(rst_n), .ped_req(ped_req),
                       .main_light(main_light), .side_light(side_light), .walk(walk));
    always #5 clk = ~clk;
    initial begin #5000000 $display("ERROR: watchdog timeout"); $finish; end

    task check;
        begin
            case (r_state)
                0: begin e_main = GREEN;  e_side = RED;    end
                1: begin e_main = YELLOW; e_side = RED;    end
                2: begin e_main = RED;    e_side = GREEN;  end
                default: begin e_main = RED; e_side = YELLOW; end
            endcase
            e_walk = (r_state == 2);
            if (main_light !== e_main || side_light !== e_side || walk !== e_walk) begin
                $display("FAIL: t=%0t phase=%0d timer=%0d pend=%b main=%b side=%b walk=%b expected main=%b side=%b walk=%b",
                         $time, r_state, r_timer, r_pend, main_light, side_light, walk, e_main, e_side, e_walk);
                errors = errors + 1;
            end
        end
    endtask

    task reset_model;
        begin r_state = 0; r_timer = 0; r_pend = 0; end
    endtask

    // ped_req set before the call (at negedge); one rising edge; update model; check
    task step;
        begin
            r_next = r_state;
            case (r_state)
                0: if (r_timer == MGT - 1 || (r_pend && r_timer >= MGMIN - 1)) r_next = 1;
                1: if (r_timer == MYT - 1) r_next = 2;
                2: if (r_timer == SGT - 1) r_next = 3;
                3: if (r_timer == SYT - 1) r_next = 0;
            endcase
            @(posedge clk); #1;
            if (ped_req) r_pend = 1;
            else if (r_state == 1 && r_next == 2) r_pend = 0;
            r_timer = (r_next != r_state) ? 0 : r_timer + 1;
            r_state = r_next;
            check;
            @(negedge clk);
        end
    endtask

    // advance (ped_req low) until the model is at phase p with timer t
    task goto(input integer p, input integer t);
        begin
            ped_req = 0;
            while (!(r_state == p && r_timer == t)) step;
        end
    endtask

    initial begin
        reset_model;
        #1 rst_n = 0;
        #2 check;
        #9 rst_n = 1;
        // two full normal cycles
        for (i = 0; i < 2 * (MGT + MYT + SGT + SYT); i = i + 1) step;
        // pedestrian pulse at every timer value of MG
        for (j = 0; j < MGT; j = j + 1) begin
            goto(0, j);
            ped_req = 1; step; ped_req = 0;
            goto(3, 0);
        end
        // pedestrian pulse in every cycle of MY, SG, SY
        for (j = 0; j < MYT; j = j + 1) begin goto(1, j); ped_req = 1; step; ped_req = 0; goto(1, MYT - 1); step; end
        for (j = 0; j < SGT; j = j + 1) begin goto(2, j); ped_req = 1; step; ped_req = 0; goto(3, SYT - 1); step; end
        for (j = 0; j < SYT; j = j + 1) begin goto(3, j); ped_req = 1; step; ped_req = 0; goto(0, MGMIN); end
        // request exactly on the edge that enters SG (must survive the clear)
        goto(1, MYT - 1); ped_req = 1; step; ped_req = 0;
        for (i = 0; i < 30; i = i + 1) step;
        // held request
        ped_req = 1;
        for (i = 0; i < 60; i = i + 1) step;
        ped_req = 0;
        // random, sparse and dense
        for (i = 0; i < 4000; i = i + 1) begin
            ped_req = (i < 2000) ? (($random & 15) == 0) : $random;
            step;
        end
        // async reset in the middle of SY with a pending request
        goto(2, 1); ped_req = 1; step; ped_req = 0; goto(3, 1);
        rst_n = 0; #1 reset_model; check; #2 rst_n = 1;
        for (i = 0; i < 60; i = i + 1) step;
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
