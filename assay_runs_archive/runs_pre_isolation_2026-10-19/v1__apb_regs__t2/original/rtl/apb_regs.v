module apb_regs (
    input  wire        pclk,
    input  wire        presetn,
    // APB3 slave interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    // hardware side
    input  wire [3:0]  hw_status,
    input  wire [3:0]  hw_event,
    output wire [7:0]  ctrl_out,
    output wire        irq
);
    localparam [7:0] ADDR_CTRL       = 8'h00;
    localparam [7:0] ADDR_STATUS     = 8'h04;
    localparam [7:0] ADDR_INT_STATUS = 8'h08;
    localparam [7:0] ADDR_INT_EN     = 8'h0C;

    localparam [7:0] CTRL_RESET = 8'h10;

    reg [7:0] ctrl;
    reg [3:0] int_status;
    reg [3:0] int_en;

    // ------------------------------------------------------------------
    // Address decode / transfer qualification
    // ------------------------------------------------------------------
    wire access   = psel && penable;
    wire wr_xfer  = access &&  pwrite;
    wire rd_xfer  = access && !pwrite;

    wire hit_ctrl = (paddr == ADDR_CTRL);
    wire hit_stat = (paddr == ADDR_STATUS);
    wire hit_ists = (paddr == ADDR_INT_STATUS);
    wire hit_ien  = (paddr == ADDR_INT_EN);
    wire mapped   = hit_ctrl | hit_stat | hit_ists | hit_ien;

    assign pready  = 1'b1;
    assign pslverr = access && !mapped;

    // ------------------------------------------------------------------
    // Interrupt logic
    // ------------------------------------------------------------------
    wire [3:0] w1c_mask = (wr_xfer && hit_ists) ? pwdata[3:0] : 4'b0000;

    assign irq      = |(int_status & int_en);
    assign ctrl_out = ctrl;

    // ------------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl       <= CTRL_RESET;
            int_status <= 4'b0000;
            int_en     <= 4'b0000;
        end else begin
            if (wr_xfer && hit_ctrl)
                ctrl <= pwdata[7:0];
            if (wr_xfer && hit_ien)
                int_en <= pwdata[3:0];
            int_status <= (int_status | hw_event) & ~w1c_mask;
        end
    end

    // ------------------------------------------------------------------
    // Read mux
    // ------------------------------------------------------------------
    always @(*) begin
        prdata = 32'h0000_0000;
        if (rd_xfer) begin
            case (paddr)
                ADDR_CTRL:       prdata = {24'h000000, ctrl};
                ADDR_STATUS:     prdata = {26'h0000000, |int_status, ctrl[0], hw_status};
                ADDR_INT_STATUS: prdata = {28'h0000000, int_status};
                ADDR_INT_EN:     prdata = {28'h0000000, int_en};
                default:         prdata = 32'h0000_0000;
            endcase
        end
    end
endmodule
