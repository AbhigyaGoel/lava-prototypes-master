module sync_fifo (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       wr_en,
    input  wire [7:0] din,
    input  wire       rd_en,
    output reg  [7:0] dout,
    output wire       full,
    output wire       empty,
    output reg  [3:0] count
);
    localparam DEPTH = 8;

    reg [7:0] mem [0:DEPTH-1];
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;

    assign full  = (count == DEPTH);
    assign empty = (count == 4'd0);

    wire wr_ok = wr_en && !full;
    wire rd_ok = rd_en && !empty;

    always @(posedge clk) begin
        if (wr_ok)
            mem[wr_ptr] <= din;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 3'd0;
            rd_ptr <= 3'd0;
            count  <= 4'd0;
            dout   <= 8'd0;
        end else begin
            if (wr_ok)
                wr_ptr <= wr_ptr + 3'd1;
            if (rd_ok) begin
                dout   <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 3'd1;
            end
            if (wr_ok && rd_ok)
                count <= count;
            else if (wr_ok)
                count <= count + 4'd1;
            else if (rd_ok)
                count <= count - 4'd1;
        end
    end
endmodule
