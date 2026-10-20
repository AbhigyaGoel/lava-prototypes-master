module timer_irq (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load,
    input  wire [15:0] load_val,
    input  wire        en,
    input  wire        auto_reload,
    input  wire        irq_clr,
    output reg  [15:0] count,
    output reg         irq
);
    reg [15:0] reload_val;

    wire expire = !load && en && (count == 16'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count      <= 16'd0;
            reload_val <= 16'd0;
        end else if (load) begin
            count      <= load_val;
            reload_val <= load_val;
        end else if (en && (count != 16'd0)) begin
            if (count == 16'd1)
                count <= auto_reload ? (reload_val - 16'd1) : 16'd0;
            else
                count <= count - 16'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            irq <= 1'b0;
        else if (irq_clr)
            irq <= 1'b0;
        else if (expire)
            irq <= 1'b1;
    end
endmodule
