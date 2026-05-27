// SPI Slave — Mode 0 (CPOL=0, CPHA=0)
// Samples MOSI on rising SCLK edge, drives MISO on falling SCLK edge
// 8-bit transfer, MSB first
// rx_valid pulses for 1 cycle when a full byte is received

module spi_slave #(
    parameter CPOL = 0,
    parameter CPHA = 0
) (
    input  logic       clk,
    input  logic       rst_n,

    // SPI bus
    input  logic       sclk,
    input  logic       mosi,
    output logic       miso,
    input  logic       cs_n,

    // User interface
    output logic [7:0] rx_data,
    output logic       rx_valid,
    input  logic [7:0] tx_data
);

    logic [2:0] bit_cnt;     // 7 downto 0
    logic [7:0] rx_shift;
    logic [7:0] tx_shift;
    logic       sclk_prev;
    logic       cs_prev;
    logic       active;

    // Synchronous edge detection
    wire sclk_rise = ( sclk && !sclk_prev);
    wire sclk_fall = (!sclk &&  sclk_prev);
    wire cs_assert = (!cs_n &&  cs_prev);  // CS just went active

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_prev <= 1'b0;
            cs_prev   <= 1'b1;
            bit_cnt   <= 3'd7;
            rx_shift  <= 8'd0;
            tx_shift  <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
            miso      <= 1'b0;
            active    <= 1'b0;
        end else begin
            sclk_prev <= sclk;
            cs_prev   <= cs_n;
            rx_valid  <= 1'b0;

            // --- CS assertion: load TX shift register and pre-drive MSB ---
            if (cs_assert) begin
                tx_shift <= tx_data;
                bit_cnt  <= 3'd7;
                active   <= 1'b1;
                miso     <= tx_data[7];
            end

            if (!cs_n && active) begin
                // Mode 0: sample MOSI on rising SCLK, drive MISO on falling SCLK

                // Rising edge: capture MOSI bit
                if (sclk_rise) begin
                    rx_shift <= {rx_shift[6:0], mosi};
                    if (bit_cnt == 3'd0) begin
                        rx_data  <= {rx_shift[6:0], mosi};
                        rx_valid <= 1'b1;
                        active   <= 1'b0;
                    end else begin
                        bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                // Falling edge: drive next MISO bit
                // After rising edge, bit_cnt has been decremented, so
                // the next bit to drive is tx_shift[bit_cnt] (new bit_cnt)
                if (sclk_fall) begin
                    miso <= tx_shift[bit_cnt];
                end
            end

            // Release MISO when CS deasserts
            if (cs_n && !cs_prev) begin
                active <= 1'b0;
                miso   <= 1'b0;
            end
        end
    end

endmodule
