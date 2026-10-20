// SPI master: 8-bit, MSB first, modes 0-3, programmable sclk half-period.
module spi_master (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,      // request a transfer (accepted only while idle)
    input  wire       cpol,       // clock polarity (idle level of sclk)
    input  wire       cpha,       // clock phase
    input  wire [3:0] div,        // sclk half-period = div + 1 clk cycles
    input  wire [7:0] tx_data,    // byte to send
    input  wire       miso,
    output reg        sclk,
    output wire       mosi,
    output reg        cs_n,
    output reg        busy,
    output reg        done,       // one-cycle completion pulse
    output reg  [7:0] rx_data     // last received byte
);
    // Transfer configuration, tracked while idle and frozen while busy
    reg       cpol_q;
    reg       cpha_q;
    reg [3:0] div_q;

    reg [3:0] hp_cnt;     // half-period counter
    reg [4:0] edge_cnt;   // sclk edges issued so far in this transfer (0..16)
    reg [7:0] tx_sr;
    reg [7:0] rx_sr;
    reg       sample_rise;

    // sclk edge selection per SPI mode
    always @(*) begin
        case ({cpol_q, cpha_q})
            2'b00:   sample_rise = 1'b1;
            2'b01:   sample_rise = 1'b0;
            2'b10:   sample_rise = 1'b0;
            default: sample_rise = 1'b1;
        endcase
    end

    wire tick       = busy && (hp_cnt == div_q);
    wire last_tick  = (edge_cnt == 5'd16);
    wire rising     = !sclk;                 // direction of the edge issued on this tick
    wire sample_now = (rising == sample_rise);
    wire first_edge = (edge_cnt == 5'd0);

    assign mosi = cs_n ? 1'b0 : tx_sr[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpol_q   <= 1'b0;
            cpha_q   <= 1'b0;
            div_q    <= 4'd0;
            hp_cnt   <= 4'd0;
            edge_cnt <= 5'd0;
            tx_sr    <= 8'd0;
            rx_sr    <= 8'd0;
            sclk     <= 1'b0;
            cs_n     <= 1'b1;
            busy     <= 1'b0;
            done     <= 1'b0;
            rx_data  <= 8'd0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                cpol_q <= cpol;
                cpha_q <= cpha;
                div_q  <= div;
                sclk   <= cpol;
                if (start) begin
                    busy     <= 1'b1;
                    cs_n     <= 1'b0;
                    hp_cnt   <= 4'd0;
                    edge_cnt <= 5'd0;
                    tx_sr    <= tx_data;
                end
            end else if (!tick) begin
                hp_cnt <= hp_cnt + 4'd1;
            end else begin
                hp_cnt <= 4'd0;
                if (last_tick) begin
                    busy    <= 1'b0;
                    cs_n    <= 1'b1;
                    done    <= 1'b1;
                    rx_data <= rx_sr;
                end else begin
                    sclk     <= ~sclk;
                    edge_cnt <= edge_cnt + 5'd1;
                    if (sample_now)
                        rx_sr <= {rx_sr[6:0], miso};
                    else if (!first_edge)
                        tx_sr <= {tx_sr[6:0], 1'b0};
                end
            end
        end
    end
endmodule
