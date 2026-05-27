# I2C IP Core

Synthesizable I2C Master and Slave IP cores written in SystemVerilog.

## Features

- **7-bit slave addressing**
- **Write and Read transactions**
- **Configurable clock frequency** — `I2C_FREQ` parameter (standard 100 kHz or fast 400 kHz)
- **Open-drain bus model** — `sda_oe`/`scl_oe` outputs; top-level uses wired-AND for correct I2C bus behavior
- **ACK error detection** — asserts `ack_error` if slave does not ACK
- **Loopback top-level** (`i2c_top`) connects master and slave on a shared bus
- Fully synthesizable (no `#delays` in RTL)

## Modules

### `i2c_master`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `start` | in | 1 | Pulse to begin a transaction |
| `rw` | in | 1 | 0 = write, 1 = read |
| `addr` | in | 7 | Slave address |
| `data_in` | in | 8 | Byte to write |
| `data_out` | out | 8 | Byte read from slave |
| `busy` | out | 1 | High during transaction |
| `ack_error` | out | 1 | Set if slave NACK received |
| `scl_oe` | out | 1 | Open-drain SCL enable (1 = pull low) |
| `sda_oe` | out | 1 | Open-drain SDA enable (1 = pull low) |
| `sda_in` | in | 1 | Sampled SDA bus value |

**Parameters:** `CLK_FREQ` (default 50_000_000), `I2C_FREQ` (default 100_000)

### `i2c_slave`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `scl` | in | 1 | SCL bus (from open-drain model) |
| `sda_in` | in | 1 | SDA bus value |
| `sda_oe` | out | 1 | Open-drain SDA enable (1 = pull low) |
| `rx_data` | out | 8 | Received byte |
| `rx_valid` | out | 1 | 1-cycle pulse when byte received |
| `tx_data` | in | 8 | Byte to send (read transaction) |

**Parameters:** `SLAVE_ADDR[6:0]` (default 7'h50)

### Open-Drain Bus Model

The top-level (`i2c_top`) implements open-drain behavior:
```systemverilog
wire scl_bus = master_scl_oe ? 1'b0 : 1'b1;
wire sda_bus = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'b1;
```
Any device that asserts its `_oe` signal pulls the bus low; otherwise it floats high (simulating pull-up resistors).

## Simulation

```bash
# Compile and run (requires iverilog)
make sim

# View waveform (requires gtkwave)
make wave

# Clean build artifacts
make clean
```

Install tools on Ubuntu/Debian:
```bash
sudo apt-get install iverilog gtkwave
```

## Testbench

The testbench (`tb/i2c_tb.sv`) instantiates `i2c_top` and:
1. Sends a write transaction: master → slave `0x50`, data = `0xBE`
2. Sends a second write: data = `0xA3`
3. Verifies slave `rx_data` matches and no `ack_error` is set
4. Prints `[PASS]` / `[FAIL]` and a summary

Simulation parameters: `CLK_FREQ=10MHz`, `I2C_FREQ=500kHz` (fast sim)
