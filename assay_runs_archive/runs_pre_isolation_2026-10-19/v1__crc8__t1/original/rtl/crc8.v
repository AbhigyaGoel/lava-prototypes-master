module crc8 (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clear,
    input  wire       valid,
    input  wire [7:0] data,
    output reg  [7:0] crc
);
    localparam [7:0] POLY = 8'h07;
    localparam [7:0] INIT = 8'h00;

    function [7:0] crc8_byte(input [7:0] c, input [7:0] d);
        integer i;
        reg [7:0] x;
        begin
            x = c ^ d;
            for (i = 0; i < 7; i = i + 1)
                x = x[7] ? ((x << 1) ^ POLY) : (x << 1);
            crc8_byte = x;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            crc <= INIT;
        else if (valid)
            crc <= crc8_byte(crc, data);
        else if (clear)
            crc <= INIT;
    end
endmodule
