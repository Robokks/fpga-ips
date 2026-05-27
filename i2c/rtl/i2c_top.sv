// I2C Top-Level (Loopback)
// Models open-drain SDA/SCL using wired-AND:
//   bus line = 1 only when ALL drivers release it (oe=0)
//              = 0 if ANY driver pulls it low (oe=1)
// Compatible with iverilog -g2012

module i2c_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter I2C_FREQ  = 100_000,
    parameter [6:0] SLAVE_ADDR = 7'h50
) (
    input  logic       clk,
    input  logic       rst_n,

    // Master user interface
    input  logic       start,
    input  logic       rw,
    input  logic [6:0] addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic       busy,
    output logic       ack_error,

    // Slave user interface
    output logic [7:0] slave_rx_data,
    output logic       slave_rx_valid,
    input  logic [7:0] slave_tx_data
);

    // Open-drain enable signals
    logic master_scl_oe;
    logic master_sda_oe;
    logic slave_sda_oe;

    // Wired-AND bus (open-drain): high unless any driver pulls low
    wire scl_bus = master_scl_oe ? 1'b0 : 1'b1;
    wire sda_bus = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'b1;

    i2c_master #(
        .CLK_FREQ (CLK_FREQ),
        .I2C_FREQ (I2C_FREQ)
    ) u_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .rw        (rw),
        .addr      (addr),
        .data_in   (data_in),
        .data_out  (data_out),
        .busy      (busy),
        .ack_error (ack_error),
        .scl_oe    (master_scl_oe),
        .sda_oe    (master_sda_oe),
        .sda_in    (sda_bus)
    );

    i2c_slave #(
        .SLAVE_ADDR (SLAVE_ADDR)
    ) u_slave (
        .clk      (clk),
        .rst_n    (rst_n),
        .scl      (scl_bus),
        .sda_in   (sda_bus),
        .sda_oe   (slave_sda_oe),
        .rx_data  (slave_rx_data),
        .rx_valid (slave_rx_valid),
        .tx_data  (slave_tx_data)
    );

endmodule
