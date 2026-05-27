// I2C Slave — 7-bit address matching, write and read
// Detects START (SDA falls while SCL=H) and STOP (SDA rises while SCL=H)
// Samples SDA on rising SCL edge, ACKs by pulling SDA low
// sda_oe=1 means drive SDA low (ACK or data-bit=0)

module i2c_slave #(
    parameter [6:0] SLAVE_ADDR = 7'h50
) (
    input  logic       clk,
    input  logic       rst_n,

    // I2C bus (open-drain resolved in top-level)
    input  logic       scl,
    input  logic       sda_in,
    output logic       sda_oe,   // 1 = pull SDA low

    // User interface
    output logic [7:0] rx_data,
    output logic       rx_valid, // 1-cycle pulse
    input  logic [7:0] tx_data   // byte to send back (read transaction)
);

    // FSM states
    localparam S_IDLE     = 3'd0;
    localparam S_ADDR     = 3'd1;  // receive 8 bits (7 addr + rw)
    localparam S_ACK_ADDR = 3'd2;  // send ACK for address
    localparam S_DATA     = 3'd3;  // receive 8 data bits (write)
    localparam S_ACK_DATA = 3'd4;  // send ACK for data byte
    localparam S_TX_DATA  = 3'd5;  // send 8 data bits (read)
    localparam S_TX_ACK   = 3'd6;  // receive ACK/NACK from master (read)

    logic [2:0] state;
    logic [2:0] bit_cnt;    // counts 7..0
    logic [7:0] shift_reg;  // RX shift register
    logic [7:0] tx_shift;   // TX shift register
    logic       rw_bit;     // saved R/W bit from address phase

    // Registered signals for edge detection
    logic scl_prev;
    logic sda_prev;

    // Synchronous edge / condition detection
    wire scl_rise  = ( scl && !scl_prev);
    wire scl_fall  = (!scl &&  scl_prev);
    wire start_det = (!sda_in &&  sda_prev) &&  scl; // SDA falls, SCL=H
    wire stop_det  = ( sda_in && !sda_prev) &&  scl; // SDA rises, SCL=H

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_prev  <= 1'b1;
            sda_prev  <= 1'b1;
            state     <= S_IDLE;
            bit_cnt   <= 3'd7;
            shift_reg <= 8'd0;
            tx_shift  <= 8'd0;
            rw_bit    <= 1'b0;
            sda_oe    <= 1'b0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            scl_prev <= scl;
            sda_prev <= sda_in;
            rx_valid <= 1'b0;

            // STOP: return to idle
            if (stop_det) begin
                state  <= S_IDLE;
                sda_oe <= 1'b0;

            // START: begin address reception
            end else if (start_det) begin
                state     <= S_ADDR;
                bit_cnt   <= 3'd7;
                shift_reg <= 8'd0;
                sda_oe    <= 1'b0; // release SDA during reception

            end else begin
                case (state)

                    // ---------------------------------------------------
                    S_IDLE: begin
                        sda_oe <= 1'b0;
                    end

                    // ---------------------------------------------------
                    // Receive 8 bits: addr[6:0] + rw (MSB first)
                    // Sample SDA on each rising SCL edge
                    S_ADDR: begin
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                            if (bit_cnt == 3'd0) begin
                                // All 8 bits received
                                rw_bit <= sda_in; // last bit = rw
                                state  <= S_ACK_ADDR;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    // ---------------------------------------------------
                    // ACK address phase:
                    //   SCL FALL (9th): pull SDA low (ACK) if address matches
                    //   SCL HIGH:       hold SDA low
                    //   SCL FALL (10th): release SDA, transition
                    // We use a 1-bit sub-state tracked by sda_oe:
                    //   sda_oe=0 before first fall → set ACK
                    //   sda_oe=1 → release after second fall
                    S_ACK_ADDR: begin
                        if (scl_fall) begin
                            if (!sda_oe) begin
                                // First falling edge: assert ACK if address matches
                                // shift_reg[7:1] = addr, shift_reg[0] = rw (but rw was
                                // shifted in last — use rw_bit which was captured separately)
                                // Actually: shift_reg holds all 8 bits including the rw bit
                                // at position 0, and addr at positions [7:1]
                                if (shift_reg[7:1] == SLAVE_ADDR) begin
                                    sda_oe <= 1'b1; // ACK: pull SDA low
                                end else begin
                                    state <= S_IDLE; // NACK: wrong address
                                end
                            end else begin
                                // Second falling edge: release SDA, move on
                                sda_oe <= 1'b0;
                                bit_cnt   <= 3'd7;
                                shift_reg <= 8'd0;
                                if (!rw_bit) begin
                                    state <= S_DATA;    // write: receive data
                                end else begin
                                    tx_shift <= tx_data;
                                    state    <= S_TX_DATA;  // read: send data
                                end
                            end
                        end
                    end

                    // ---------------------------------------------------
                    // DATA (write): receive 8 data bits, MSB first
                    S_DATA: begin
                        sda_oe <= 1'b0; // release SDA for master to drive
                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                            if (bit_cnt == 3'd0) begin
                                rx_data  <= {shift_reg[6:0], sda_in};
                                rx_valid <= 1'b1;
                                state    <= S_ACK_DATA;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    // ---------------------------------------------------
                    // ACK data: same two-fall pattern as ACK_ADDR
                    S_ACK_DATA: begin
                        if (scl_fall) begin
                            if (!sda_oe) begin
                                sda_oe <= 1'b1; // ACK
                            end else begin
                                sda_oe  <= 1'b0;
                                bit_cnt <= 3'd7;
                                shift_reg <= 8'd0;
                                state   <= S_DATA; // ready for next byte
                            end
                        end
                    end

                    // ---------------------------------------------------
                    // TX_DATA (read): send 8 data bits, MSB first
                    // Drive SDA on falling SCL edges
                    S_TX_DATA: begin
                        if (scl_fall) begin
                            // Drive the current bit
                            sda_oe <= ~tx_shift[bit_cnt];
                        end else if (scl_rise) begin
                            if (bit_cnt == 3'd0) begin
                                sda_oe <= 1'b0;  // release after last bit
                                state  <= S_TX_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    // ---------------------------------------------------
                    // TX_ACK: receive master ACK/NACK
                    S_TX_ACK: begin
                        if (scl_fall) begin
                            sda_oe <= 1'b0; // release
                        end else if (scl_rise) begin
                            // If master NACK (sda_in=1): stop; if ACK: could repeat
                            state <= S_IDLE;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
