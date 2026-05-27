// UART Top-Level
// Instantiates UART TX and RX with shared clock/baud parameters
// TX: parallel-in / serial-out
// RX: serial-in / parallel-out (center-sampled)

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst_n,

    // TX interface
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,
    output logic       tx,

    // RX interface
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx       (tx)
    );

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx       (rx),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

endmodule
