// SPI Master — Mode 0 (CPOL=0, CPHA=0)
// Data captured on rising SCLK, shifted out on falling SCLK, MSB first
// Transfer sequence (8 bits × 2 half-periods = 16 phases):
//   Phase  0 (SCLK=0): pre-drive tx[7] on MOSI, assert CS_N
//   Phase  1 (SCLK=1): sample MISO → rx[7]
//   Phase  2 (SCLK=0): drive tx[6]
//   Phase  3 (SCLK=1): sample MISO → rx[6]
//   ...
//   Phase 14 (SCLK=0): drive tx[0]
//   Phase 15 (SCLK=1): sample MISO → rx[0]; then go to DONE

module spi_master #(
    parameter CLK_DIV = 4,   // SCLK half-period = CLK_DIV system clocks
    parameter CPOL    = 0,
    parameter CPHA    = 0
) (
    input  logic       clk,
    input  logic       rst_n,

    // User interface
    input  logic       start,
    input  logic [7:0] mosi_data,
    output logic [7:0] miso_data,
    output logic       done,
    output logic       busy,

    // SPI bus
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs_n
);

    localparam S_IDLE     = 2'd0;
    localparam S_TRANSFER = 2'd1;
    localparam S_DONE     = 2'd2;

    logic [1:0]  state;
    logic [7:0]  clk_cnt;   // half-period counter: 0..CLK_DIV-1
    logic [3:0]  phase;     // transfer phase: 0..15
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic        sclk_r;

    // Bit index from phase: phase 0/1→bit7, 2/3→bit6, ..., 14/15→bit0
    wire [2:0] bit_idx = 3'd7 - phase[3:1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_cnt   <= 8'd0;
            phase     <= 4'd0;
            tx_shift  <= 8'd0;
            rx_shift  <= 8'd0;
            sclk_r    <= 1'b0;
            cs_n      <= 1'b1;
            mosi      <= 1'b0;
            miso_data <= 8'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            done <= 1'b0; // default: de-assert

            case (state)
                // ----------------------------------------------------------
                S_IDLE: begin
                    sclk_r  <= 1'b0;
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    clk_cnt <= 8'd0;
                    phase   <= 4'd0;
                    if (start) begin
                        tx_shift <= mosi_data;
                        cs_n     <= 1'b0;
                        mosi     <= mosi_data[7]; // pre-drive MSB
                        busy     <= 1'b1;
                        state    <= S_TRANSFER;
                    end
                end

                // ----------------------------------------------------------
                // Each phase lasts CLK_DIV clocks.
                // Even phase → SCLK=0 → MOSI drives current bit
                // Odd  phase → SCLK=1 → sample MISO
                S_TRANSFER: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= 8'd0;

                        if (phase[0] == 1'b0) begin
                            // ---- Rising edge: SCLK 0→1 ----
                            sclk_r <= 1'b1;
                            // Sample MISO into rx_shift MSB first
                            rx_shift <= {rx_shift[6:0], miso};

                            if (phase == 4'd14) begin
                                // Last rising edge — done after this
                                state <= S_DONE;
                            end else begin
                                phase <= phase + 1'b1;
                            end
                        end else begin
                            // ---- Falling edge: SCLK 1→0 ----
                            sclk_r <= 1'b0;
                            phase  <= phase + 1'b1;
                            // Drive next MOSI bit (bit for phase+1, i.e. phase+1 is even)
                            // bit_idx for phase+1 = 7 - ((phase+1) >> 1)
                            mosi <= tx_shift[7 - ((phase + 1) >> 1)];
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // ----------------------------------------------------------
                S_DONE: begin
                    sclk_r    <= 1'b0;
                    cs_n      <= 1'b1;
                    miso_data <= rx_shift; // all 8 bits captured during TRANSFER
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign sclk = sclk_r;

endmodule
