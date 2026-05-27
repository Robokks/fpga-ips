// I2C Master — 7-bit addressing, write and read
// Open-drain outputs: scl_oe=1 → pull low; scl_oe=0 → release (high via pull-up)
//
// Timing for each bit:
//   SCL-LOW  half (scl_phase=0): SDA is set up (stable)
//   SCL-HIGH half (scl_phase=1): slave samples SDA; master samples for ACK/read
//
// START condition: SDA falls while SCL=H, then SCL falls
// STOP  condition: SDA rises while SCL=H

module i2c_master #(
    parameter CLK_FREQ = 50_000_000,
    parameter I2C_FREQ = 100_000
) (
    input  logic       clk,
    input  logic       rst_n,

    // User interface
    input  logic       start,
    input  logic       rw,           // 0=write, 1=read
    input  logic [6:0] addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic       busy,
    output logic       ack_error,

    // Open-drain bus outputs
    output logic       scl_oe,       // 1 = pull SCL low
    output logic       sda_oe,       // 1 = pull SDA low
    input  logic       sda_in        // current SDA bus value
);

    localparam HALF = CLK_FREQ / (2 * I2C_FREQ);

    // FSM states
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;  // generate START condition
    localparam S_ADDR  = 3'd2;  // send 8 bits: addr[6:0] + rw
    localparam S_MACK  = 3'd3;  // receive slave ACK
    localparam S_DATA  = 3'd4;  // send/receive 8 data bits
    localparam S_DACK  = 3'd5;  // data ACK phase
    localparam S_STOP  = 3'd6;  // generate STOP condition

    logic [2:0]  state;
    logic [15:0] cnt;        // half-period counter
    logic        scl_r;      // 1=SCL high, 0=SCL low
    logic        sda_r;      // 1=release SDA, 0=pull SDA low
    logic        scl_phase;  // 0=SCL-low half, 1=SCL-high half
    logic [3:0]  bit_cnt;    // bit counter (7..0)
    logic [7:0]  shift_reg;  // TX shift register
    logic [7:0]  rx_shift;   // RX shift register

    wire half_tick = (cnt == HALF - 1);

    // Open-drain: pull low when we want 0
    assign scl_oe = ~scl_r;
    assign sda_oe = ~sda_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cnt       <= 16'd0;
            scl_r     <= 1'b1;
            sda_r     <= 1'b1;
            scl_phase <= 1'b0;
            bit_cnt   <= 4'd0;
            shift_reg <= 8'd0;
            rx_shift  <= 8'd0;
            data_out  <= 8'd0;
            busy      <= 1'b0;
            ack_error <= 1'b0;
        end else begin
            cnt <= cnt + 1'b1;

            case (state)

                // -------------------------------------------------------
                S_IDLE: begin
                    scl_r     <= 1'b1; // SCL high
                    sda_r     <= 1'b1; // SDA high
                    scl_phase <= 1'b0;
                    cnt       <= 16'd0;
                    busy      <= 1'b0;
                    if (start) begin
                        busy      <= 1'b1;
                        ack_error <= 1'b0;
                        shift_reg <= {addr, rw}; // [7:1]=addr, [0]=rw
                        state     <= S_START;
                    end
                end

                // -------------------------------------------------------
                // START: SDA falls while SCL=H, then SCL falls
                // scl_phase=0: wait one half-period then pull SDA low
                // scl_phase=1: wait one half-period then pull SCL low
                S_START: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            sda_r     <= 1'b0;  // START: SDA falls (SCL still high)
                            scl_phase <= 1'b1;
                        end else begin
                            scl_r     <= 1'b0;  // SCL falls (begin first bit)
                            scl_phase <= 1'b0;
                            // Pre-drive SDA with MSB of address
                            sda_r     <= shift_reg[7];
                            bit_cnt   <= 4'd7;
                            state     <= S_ADDR;
                        end
                    end
                end

                // -------------------------------------------------------
                // ADDR: transmit 8 bits of {addr[6:0], rw}, MSB first
                // SDA is set up at the start of each SCL-low phase
                // SCL-low phase: SDA is stable → SCL rises → slave samples → SCL falls
                S_ADDR: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            // SCL-low → SCL-high transition (rising edge)
                            scl_r     <= 1'b1;
                            scl_phase <= 1'b1;
                        end else begin
                            // SCL-high → SCL-low transition (falling edge)
                            scl_r     <= 1'b0;
                            scl_phase <= 1'b0;
                            if (bit_cnt == 4'd0) begin
                                // All 8 bits sent; release SDA for slave ACK
                                sda_r <= 1'b1;
                                state <= S_MACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                                sda_r   <= shift_reg[bit_cnt - 1]; // next bit (OLD bit_cnt)
                            end
                        end
                    end
                end

                // -------------------------------------------------------
                // MACK: release SDA, clock one ACK bit, sample slave ACK
                // Entry: SCL=L, SDA=released(H)
                // SCL rises → slave must pull SDA low for ACK
                // SCL falls → master samples sda_in; set up data
                S_MACK: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            scl_r     <= 1'b1;
                            scl_phase <= 1'b1;
                        end else begin
                            // Sample ACK at falling edge of ACK clock
                            if (sda_in) ack_error <= 1'b1; // NACK if SDA still high
                            scl_r     <= 1'b0;
                            scl_phase <= 1'b0;
                            // Prepare data phase
                            shift_reg <= data_in;
                            bit_cnt   <= 4'd7;
                            if (!rw)
                                sda_r <= data_in[7]; // write: setup first data bit
                            else
                                sda_r <= 1'b1;        // read: release SDA
                            state <= S_DATA;
                        end
                    end
                end

                // -------------------------------------------------------
                // DATA: transmit (write) or receive (read) 8 data bits
                S_DATA: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            scl_r     <= 1'b1;
                            scl_phase <= 1'b1;
                        end else begin
                            scl_r     <= 1'b0;
                            scl_phase <= 1'b0;
                            // For read: sample SDA while SCL was high
                            if (rw)
                                rx_shift <= {rx_shift[6:0], sda_in};
                            if (bit_cnt == 4'd0) begin
                                // All 8 data bits done
                                if (rw) begin
                                    data_out <= {rx_shift[6:0], sda_in};
                                    sda_r    <= 1'b1; // master NACK = end of read
                                end else begin
                                    sda_r <= 1'b1; // release for slave data ACK
                                end
                                state <= S_DACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                                if (!rw)
                                    sda_r <= shift_reg[bit_cnt - 1];
                            end
                        end
                    end
                end

                // -------------------------------------------------------
                // DACK: data ACK phase
                S_DACK: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            scl_r     <= 1'b1;
                            scl_phase <= 1'b1;
                        end else begin
                            if (!rw && sda_in) ack_error <= 1'b1;
                            scl_r     <= 1'b0;
                            scl_phase <= 1'b0;
                            sda_r     <= 1'b0; // pull SDA low before STOP
                            state     <= S_STOP;
                        end
                    end
                end

                // -------------------------------------------------------
                // STOP: SCL rises, then SDA rises (STOP condition)
                // Entry: SCL=L, SDA=L
                // scl_phase=0: SCL rises (SDA still low)
                // scl_phase=1: SDA rises while SCL=H (STOP)
                S_STOP: begin
                    if (half_tick) begin
                        cnt <= 16'd0;
                        if (!scl_phase) begin
                            scl_r     <= 1'b1; // SCL rises
                            scl_phase <= 1'b1;
                        end else begin
                            sda_r <= 1'b1; // SDA rises while SCL=H → STOP
                            busy  <= 1'b0;
                            state <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
