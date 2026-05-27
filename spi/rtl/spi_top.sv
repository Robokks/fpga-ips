// SPI Top-Level (Loopback)
// Connects SPI master and slave together for verification/demo.
// Master MOSI → Slave MOSI (master sends, slave receives)
// Slave MISO  → Master MISO (slave sends back, master receives)

module spi_top #(
    parameter CLK_DIV = 4,
    parameter CPOL    = 0,
    parameter CPHA    = 0
) (
    input  logic       clk,
    input  logic       rst_n,

    // Master user interface
    input  logic       start,
    input  logic [7:0] master_tx_data,
    output logic [7:0] master_rx_data,
    output logic       done,
    output logic       busy,

    // Slave user interface
    output logic [7:0] slave_rx_data,
    output logic       slave_rx_valid,
    input  logic [7:0] slave_tx_data
);

    // Internal SPI bus wires
    logic sclk_w;
    logic mosi_w;
    logic miso_w;
    logic cs_n_w;

    spi_master #(
        .CLK_DIV (CLK_DIV),
        .CPOL    (CPOL),
        .CPHA    (CPHA)
    ) u_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .mosi_data (master_tx_data),
        .miso_data (master_rx_data),
        .done      (done),
        .busy      (busy),
        .sclk      (sclk_w),
        .mosi      (mosi_w),
        .miso      (miso_w),
        .cs_n      (cs_n_w)
    );

    spi_slave #(
        .CPOL (CPOL),
        .CPHA (CPHA)
    ) u_slave (
        .clk      (clk),
        .rst_n    (rst_n),
        .sclk     (sclk_w),
        .mosi     (mosi_w),
        .miso     (miso_w),
        .cs_n     (cs_n_w),
        .rx_data  (slave_rx_data),
        .rx_valid (slave_rx_valid),
        .tx_data  (slave_tx_data)
    );

endmodule
