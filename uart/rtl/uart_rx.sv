// UART Receiver
// 8N1 format: 1 start bit, 8 data bits (LSB first), 1 stop bit
// Center-samples each bit for noise immunity
// FSM: IDLE -> START -> DATA -> STOP

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid   // 1-cycle pulse when byte received
);

    localparam CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT      = CLKS_PER_BIT / 2;

    // FSM state encoding
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    logic [1:0]  state;
    logic [15:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  shift_reg;
    logic        rx_sync0, rx_sync1; // 2-FF synchroniser

    // Double-flop synchroniser (metastability protection)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // default: de-assert pulse

            case (state)
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (!rx_sync1) begin   // falling edge = start bit
                        state <= S_START;
                    end
                end

                S_START: begin
                    // Wait half a bit period to sample in the center
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        // Verify start bit is still low (not a glitch)
                        if (!rx_sync1)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    // Sample at full bit period from the center of start bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt               <= 16'd0;
                        shift_reg[bit_idx]    <= rx_sync1; // LSB first
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt  <= 16'd0;
                        if (rx_sync1) begin   // valid stop bit = high
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
