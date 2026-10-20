// Byte-to-word packer: collects 8-bit input beats into 32-bit little-endian output words.
// A beat flagged with in_last closes the current word early (zero padded, out_keep marks
// the valid bytes). Both interfaces use valid/ready handshakes.
module width_packer (
    input  wire        clk,
    input  wire        rst_n,
    // byte input
    input  wire        in_valid,
    output wire        in_ready,
    input  wire [7:0]  in_data,
    input  wire        in_last,
    // word output
    output reg         out_valid,
    input  wire        out_ready,
    output reg  [31:0] out_data,
    output reg  [3:0]  out_keep,
    output reg         out_last
);
    reg [23:0] acc;      // bytes 0..2 of the word being assembled
    reg [1:0]  count;    // bytes held in acc
    reg [31:0] word;
    reg [3:0]  keep;

    wire pop      = out_valid && out_ready;
    wire out_free = !out_valid || out_ready;
    wire full     = (count == 2'd3);
    wire closes   = full || in_last;

    // Input stalls only while the output register is occupied and cannot drain
    assign in_ready = out_free || (!full && !in_last);

    wire accept   = in_valid && in_ready;
    wire complete = accept && closes;

    // Word formed by the held bytes plus the incoming byte
    always @(*) begin
        case (count)
            2'd0:    begin word = {24'd0, in_data};            keep = 4'b0001; end
            2'd1:    begin word = {16'd0, in_data, acc[7:0]};  keep = 4'b0011; end
            2'd2:    begin word = {8'd0, in_data, acc[15:0]};  keep = 4'b0111; end
            default: begin word = {in_data, acc[23:0]};        keep = 4'b1111; end
        endcase
    end

    // Output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 32'd0;
            out_keep  <= 4'd0;
            out_last  <= 1'b0;
        end else if (pop) begin
            out_valid <= 1'b0;
        end else if (complete) begin
            out_valid <= 1'b1;
            out_data  <= word;
            out_keep  <= keep;
            out_last  <= in_last;
        end
    end

    // Accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc   <= 24'd0;
            count <= 2'd0;
        end else if (accept) begin
            if (complete) begin
                count <= 2'd0;
            end else begin
                count <= count + 2'd1;
                case (count)
                    2'd0:    acc[7:0]   <= in_data;
                    2'd1:    acc[15:8]  <= in_data;
                    default: acc[23:16] <= in_data;
                endcase
            end
        end
    end
endmodule
