`timescale 1ns/1ps
module tb;
    localparam RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;
    reg clk = 0, rst_n = 1, ped_req = 0;
    wire [2:0] main_light, side_light;
    wire walk;
    integer errors = 0, n;

    traffic_light dut (.clk(clk), .rst_n(rst_n), .ped_req(ped_req),
                       .main_light(main_light), .side_light(side_light), .walk(walk));
    always #5 clk = ~clk;
    initial begin #100000 $display("ERROR: watchdog timeout"); $finish; end

    task expect_lights(input [2:0] m, input [2:0] s, input w);
        if (main_light !== m || side_light !== s || walk !== w) begin
            $display("FAIL: t=%0t main=%b side=%b walk=%b expected main=%b side=%b walk=%b",
                     $time, main_light, side_light, walk, m, s, w);
            errors = errors + 1;
        end
    endtask

    // count consecutive cycles (sampled at negedge) that main_light stays at value v
    task measure_main(input [2:0] v, output integer len);
        begin
            len = 0;
            while (main_light === v) begin len = len + 1; @(negedge clk); end
        end
    endtask

    task measure_side(input [2:0] v, output integer len);
        begin
            len = 0;
            while (side_light === v) begin len = len + 1; @(negedge clk); end
        end
    endtask

    task expect_len(input integer got, input integer exp, input [8*12-1:0] name);
        if (got !== exp) begin
            $display("FAIL: %0s lasted %0d cycles, expected %0d", name, got, exp);
            errors = errors + 1;
        end
    endtask

    initial begin
        #1 rst_n = 0;
        #2 expect_lights(GREEN, RED, 0);
        #9 rst_n = 1;
        @(negedge clk);
        // first cycle after reset is the second MG cycle
        expect_lights(GREEN, RED, 0);
        measure_main(GREEN, n);  expect_len(n + 1, 8, "main green");
        expect_lights(YELLOW, RED, 0);
        measure_main(YELLOW, n); expect_len(n, 2, "main yellow");
        expect_lights(RED, GREEN, 1);
        measure_side(GREEN, n);  expect_len(n, 4, "side green");
        expect_lights(RED, YELLOW, 0);
        // pedestrian presses at the start of the next main green
        wait (main_light === GREEN);
        @(negedge clk);
        ped_req = 1; @(negedge clk); ped_req = 0;
        measure_main(GREEN, n);  expect_len(n + 1, 3, "ped green");
        expect_lights(YELLOW, RED, 0);
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
