module traffic_light #(
    parameter MAIN_GREEN_T   = 8,
    parameter MAIN_GREEN_MIN = 3,
    parameter MAIN_YELLOW_T  = 2,
    parameter SIDE_GREEN_T   = 4,
    parameter SIDE_YELLOW_T  = 3
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ped_req,
    output reg  [2:0] main_light,
    output reg  [2:0] side_light,
    output wire       walk
);
    localparam [1:0] MG = 2'd0, MY = 2'd1, SG = 2'd2, SY = 2'd3;
    localparam [2:0] RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;

    reg [1:0] state;
    reg [3:0] timer;
    reg       ped_pending;
    reg [1:0] next_state;

    always @(*) begin
        next_state = state;
        case (state)
            MG: if (timer == MAIN_GREEN_T - 1 ||
                    (ped_pending && timer == MAIN_GREEN_MIN - 1))
                    next_state = MY;
            MY: if (timer == MAIN_YELLOW_T - 1) next_state = SG;
            SG: if (timer == SIDE_GREEN_T - 1)  next_state = SY;
            SY: if (timer == MAIN_YELLOW_T - 1) next_state = MG;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= MG;
            timer       <= 4'd0;
            ped_pending <= 1'b0;
        end else begin
            state <= next_state;
            timer <= (next_state != state) ? 4'd0 : timer + 4'd1;
            if (ped_req)
                ped_pending <= 1'b1;
            else if (next_state == SG && state == MY)
                ped_pending <= 1'b0;
        end
    end

    always @(*) begin
        case (state)
            MG:      begin main_light = GREEN;  side_light = RED;    end
            MY:      begin main_light = YELLOW; side_light = RED;    end
            SG:      begin main_light = RED;    side_light = GREEN;  end
            default: begin main_light = RED;    side_light = YELLOW; end
        endcase
    end

    assign walk = (state == SG);
endmodule
