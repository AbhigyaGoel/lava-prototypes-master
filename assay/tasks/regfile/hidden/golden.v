module regfile (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       we,
    input  wire [2:0] waddr,
    input  wire [7:0] wdata,
    input  wire [2:0] raddr1,
    output wire [7:0] rdata1,
    input  wire [2:0] raddr2,
    output wire [7:0] rdata2
);
    reg [7:0] r1, r2, r3, r4, r5, r6, r7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1 <= 8'd0; r2 <= 8'd0; r3 <= 8'd0; r4 <= 8'd0;
            r5 <= 8'd0; r6 <= 8'd0; r7 <= 8'd0;
        end else if (we) begin
            case (waddr)
                3'd1: r1 <= wdata;
                3'd2: r2 <= wdata;
                3'd3: r3 <= wdata;
                3'd4: r4 <= wdata;
                3'd5: r5 <= wdata;
                3'd6: r6 <= wdata;
                3'd7: r7 <= wdata;
                default: ;
            endcase
        end
    end

    wire [63:0] regs_flat = {r7, r6, r5, r4, r3, r2, r1, 8'd0};

    assign rdata1 = (raddr1 == 3'd0)          ? 8'd0  :
                    (we && (waddr == raddr1)) ? wdata :
                                                regs_flat[raddr1*8 +: 8];
    assign rdata2 = (raddr2 == 3'd0)          ? 8'd0  :
                    (we && (waddr == raddr2)) ? wdata :
                                                regs_flat[raddr2*8 +: 8];
endmodule
