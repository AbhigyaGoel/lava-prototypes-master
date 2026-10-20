module int_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] src,
    input  wire       we,
    input  wire [1:0] addr,
    input  wire [7:0] wdata,
    input  wire       ack,
    input  wire [2:0] ack_id,
    output wire [7:0] pending,
    output wire       irq,
    output reg  [2:0] irq_id
);
    localparam ADDR_MASK = 2'd0;
    localparam ADDR_MODE = 2'd1;

    reg  [7:0] mask;
    reg  [7:0] mode;
    reg  [7:0] src_q;
    reg  [7:0] edge_pend;
    integer    i;
    integer    j;

    wire [7:0] rise    = src & ~src_q;
    wire [7:0] ack_vec = ack ? (8'b0000_0001 << ack_id) : 8'b0000_0000;
    wire [7:0] active;

    assign pending = (mode & edge_pend) | (~mode & src);
    assign active  = pending & mask;
    assign irq     = |active;

    always @(*) begin
        irq_id = 3'd0;
        for (i = 7; i >= 0; i = i - 1)
            if (active[i])
                irq_id = i;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= 8'h00;
            mode <= 8'h00;
        end else if (we) begin
            case (addr)
                ADDR_MASK: mask <= wdata;
                ADDR_MODE: mode <= wdata;
                default:   ;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            src_q <= 8'h00;
        else
            src_q <= src;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_pend <= 8'h00;
        end else begin
            for (j = 0; j < 8; j = j + 1) begin
                if (!mode[j])
                    edge_pend[j] <= 1'b0;
                else if (rise[j])
                    edge_pend[j] <= 1'b1;
                else if (ack_vec[j])
                    edge_pend[j] <= 1'b0;
            end
        end
    end
endmodule
