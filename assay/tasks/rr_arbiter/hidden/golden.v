module rr_arbiter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] req,
    output wire [3:0] grant
);
    reg [1:0] ptr;
    reg [1:0] idx;
    reg [3:0] grant_c;

    always @(*) begin
        grant_c = 4'b0000;
        idx     = ptr;
        case (ptr)
            2'd0: begin
                if      (req[0]) begin grant_c = 4'b0001; idx = 2'd0; end
                else if (req[1]) begin grant_c = 4'b0010; idx = 2'd1; end
                else if (req[2]) begin grant_c = 4'b0100; idx = 2'd2; end
                else if (req[3]) begin grant_c = 4'b1000; idx = 2'd3; end
            end
            2'd1: begin
                if      (req[1]) begin grant_c = 4'b0010; idx = 2'd1; end
                else if (req[2]) begin grant_c = 4'b0100; idx = 2'd2; end
                else if (req[3]) begin grant_c = 4'b1000; idx = 2'd3; end
                else if (req[0]) begin grant_c = 4'b0001; idx = 2'd0; end
            end
            2'd2: begin
                if      (req[2]) begin grant_c = 4'b0100; idx = 2'd2; end
                else if (req[3]) begin grant_c = 4'b1000; idx = 2'd3; end
                else if (req[0]) begin grant_c = 4'b0001; idx = 2'd0; end
                else if (req[1]) begin grant_c = 4'b0010; idx = 2'd1; end
            end
            default: begin
                if      (req[3]) begin grant_c = 4'b1000; idx = 2'd3; end
                else if (req[0]) begin grant_c = 4'b0001; idx = 2'd0; end
                else if (req[1]) begin grant_c = 4'b0010; idx = 2'd1; end
                else if (req[2]) begin grant_c = 4'b0100; idx = 2'd2; end
            end
        endcase
    end

    assign grant = grant_c;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ptr <= 2'd0;
        else if (|req)
            ptr <= idx + 2'd1;
    end
endmodule
