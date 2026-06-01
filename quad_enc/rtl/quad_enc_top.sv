// Quadrature Encoder Decoder — ABZ Interface
//
// Features:
//   - 4× decoding (counts on every A and B edge) for maximum resolution
//   - 2-stage input synchronizer (metastability protection)
//   - Programmable debounce filter (for mechanical encoders)
//   - Z index pulse: resets angle to z_preset on rising edge (when z_reset_en=1)
//   - Load initial angle: preload counter via load_en / init_angle
//   - Direction output, error flag (illegal AB transition), initialized flag
//
// Quadrature state forward sequence (CW): AB = 00→01→11→10→00...
// Quadrature state backward sequence (CCW): AB = 00→10→11→01→00...
//
// Priority (highest first):
//   1. rst_n  (asynchronous reset to 0)
//   2. load_en (synchronous load of init_angle)
//   3. Z rising edge reset (if z_reset_en)
//   4. Quadrature count (+1 / -1)

module quad_enc_top #(
    parameter CNT_WIDTH    = 32,  // Angle counter bit width
    parameter SYNC_STAGES  = 2,   // Input synchronizer depth (≥2 recommended)
    parameter DEBOUNCE_LEN = 8    // Cycles input must be stable before accepted
                                  // Set to 0 for optical/clean encoder inputs
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Raw encoder inputs (directly from FPGA I/O pins)
    input  logic                  a_in,        // Quadrature channel A
    input  logic                  b_in,        // Quadrature channel B
    input  logic                  z_in,        // Index / Z channel

    // Control
    input  logic                  z_reset_en,  // 1 = reset counter on Z rising edge
    input  logic [CNT_WIDTH-1:0]  z_preset,    // Counter value to load on Z (typically 0)
    input  logic                  load_en,     // Pulse: preload counter with init_angle
    input  logic [CNT_WIDTH-1:0]  init_angle,  // Preload value

    // Outputs
    output logic [CNT_WIDTH-1:0]  angle,       // Current position count (unsigned)
    output logic                  dir,         // 1 = CW/forward, 0 = CCW/backward
    output logic                  z_pulse,     // 1-cycle pulse on detected Z rising edge
    output logic                  error,       // 1-cycle pulse: illegal AB transition
    output logic                  initialized  // Latches high after first Z reset
);

    // ================================================================
    // Input synchronizer (2-stage shift register per signal)
    // ================================================================
    logic [SYNC_STAGES-1:0] a_sync_r, b_sync_r, z_sync_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_sync_r <= '0;
            b_sync_r <= '0;
            z_sync_r <= '0;
        end else begin
            a_sync_r <= {a_sync_r[SYNC_STAGES-2:0], a_in};
            b_sync_r <= {b_sync_r[SYNC_STAGES-2:0], b_in};
            z_sync_r <= {z_sync_r[SYNC_STAGES-2:0], z_in};
        end
    end

    wire a_synced = a_sync_r[SYNC_STAGES-1];
    wire b_synced = b_sync_r[SYNC_STAGES-1];
    wire z_synced = z_sync_r[SYNC_STAGES-1];

    // ================================================================
    // Debounce filter (per signal)
    // Input must differ from output for DEBOUNCE_LEN consecutive cycles
    // before the output flips.  DEBOUNCE_LEN=0 → pass-through.
    // ================================================================
    logic [15:0] a_db_cnt, b_db_cnt, z_db_cnt;
    logic        a_filt,   b_filt,   z_filt;

    // Generate debounce or wire-through based on parameter
    generate
        if (DEBOUNCE_LEN == 0) begin : g_no_debounce
            assign a_filt = a_synced;
            assign b_filt = b_synced;
            assign z_filt = z_synced;
        end else begin : g_debounce
            // Channel A
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    a_db_cnt <= 16'd0; a_filt <= 1'b0;
                end else if (a_synced != a_filt) begin
                    if (a_db_cnt == DEBOUNCE_LEN - 1) begin
                        a_filt   <= a_synced;
                        a_db_cnt <= 16'd0;
                    end else
                        a_db_cnt <= a_db_cnt + 1'b1;
                end else
                    a_db_cnt <= 16'd0;
            end
            // Channel B
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    b_db_cnt <= 16'd0; b_filt <= 1'b0;
                end else if (b_synced != b_filt) begin
                    if (b_db_cnt == DEBOUNCE_LEN - 1) begin
                        b_filt   <= b_synced;
                        b_db_cnt <= 16'd0;
                    end else
                        b_db_cnt <= b_db_cnt + 1'b1;
                end else
                    b_db_cnt <= 16'd0;
            end
            // Channel Z
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    z_db_cnt <= 16'd0; z_filt <= 1'b0;
                end else if (z_synced != z_filt) begin
                    if (z_db_cnt == DEBOUNCE_LEN - 1) begin
                        z_filt   <= z_synced;
                        z_db_cnt <= 16'd0;
                    end else
                        z_db_cnt <= z_db_cnt + 1'b1;
                end else
                    z_db_cnt <= 16'd0;
            end
        end
    endgenerate

    // ================================================================
    // Edge detection for Z (rising edge → z_pulse)
    // ================================================================
    logic z_prev;
    wire  z_rise = z_filt && !z_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) z_prev <= 1'b0;
        else        z_prev <= z_filt;
    end

    // ================================================================
    // 4× Quadrature decode — lookup table
    //
    // Index = {A_prev, B_prev, A_curr, B_curr}
    //
    // Forward  (+1 CW):  0001, 0111, 1110, 1000
    // Backward (-1 CCW): 0010, 0100, 1011, 1101
    // No change:         0000, 0101, 1010, 1111
    // Error (2-bit jump): 0011, 0110, 1001, 1100
    // ================================================================
    logic a_prev, b_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_prev <= 1'b0;
            b_prev <= 1'b0;
        end else begin
            a_prev <= a_filt;
            b_prev <= b_filt;
        end
    end

    wire [3:0] quad_state = {a_prev, b_prev, a_filt, b_filt};

    // Decode as one-hot enables
    wire step_fwd = (quad_state == 4'h1) || (quad_state == 4'h7) ||
                    (quad_state == 4'h8) || (quad_state == 4'hE);
    wire step_rev = (quad_state == 4'h2) || (quad_state == 4'h4) ||
                    (quad_state == 4'hB) || (quad_state == 4'hD);
    wire step_err = (quad_state == 4'h3) || (quad_state == 4'h6) ||
                    (quad_state == 4'h9) || (quad_state == 4'hC);

    // ================================================================
    // Angle counter + control logic
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            angle       <= {CNT_WIDTH{1'b0}};
            dir         <= 1'b1;
            z_pulse     <= 1'b0;
            error       <= 1'b0;
            initialized <= 1'b0;
        end else begin
            // Default: clear single-cycle pulses
            z_pulse <= 1'b0;
            error   <= 1'b0;

            // Priority 1: load_en (software preload, highest run-time priority)
            if (load_en) begin
                angle <= init_angle;
            end

            // Priority 2: Z index rising edge
            else if (z_rise) begin
                z_pulse <= 1'b1;
                if (z_reset_en) begin
                    angle       <= z_preset;
                    initialized <= 1'b1;
                end
            end

            // Priority 3: quadrature count
            else begin
                if (step_fwd) begin
                    angle <= angle + 1'b1;
                    dir   <= 1'b1;
                end else if (step_rev) begin
                    angle <= angle - 1'b1;
                    dir   <= 1'b0;
                end else if (step_err) begin
                    error <= 1'b1; // illegal transition — do not update angle
                end
            end
        end
    end

endmodule
