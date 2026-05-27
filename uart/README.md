# UART IP Core

A synthesizable, parameterizable UART (Universal Asynchronous Receiver/Transmitter) core written in SystemVerilog.

## Features

- Configurable baud rate via `BAUD_RATE` parameter
- Configurable system clock via `CLK_FREQ` parameter
- 8N1 framing (8 data bits, no parity, 1 stop bit)
- Full duplex operation (independent TX and RX)
- FIFO-less design — simple handshake interface
- Synthesizable, no delay statements in RTL
- Center-sampling RX for noise immunity

## Port Descriptions

### `uart_top`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`      | in  | 1  | System clock |
| `rst_n`    | in  | 1  | Active-low synchronous reset |
| `tx_data`  | in  | 8  | Byte to transmit |
| `tx_valid` | in  | 1  | Assert to start transmission |
| `tx_ready` | out | 1  | High when TX is idle (ready for next byte) |
| `tx`       | out | 1  | UART TX serial output |
| `rx`       | in  | 1  | UART RX serial input |
| `rx_data`  | out | 8  | Received byte |
| `rx_valid` | out | 1  | One-cycle pulse: received byte is valid |
| `rx_ready` | in  | 1  | Tie high if no flow control needed |

### `uart_tx`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`      | in  | 1  | System clock |
| `rst_n`    | in  | 1  | Active-low synchronous reset |
| `tx_data`  | in  | 8  | Byte to transmit |
| `tx_valid` | in  | 1  | Start transmission when high and tx_ready is high |
| `tx_ready` | out | 1  | Transmitter is idle |
| `tx`       | out | 1  | Serial output line |

### `uart_rx`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`      | in  | 1  | System clock |
| `rst_n`    | in  | 1  | Active-low synchronous reset |
| `rx`       | in  | 1  | Serial input line |
| `rx_data`  | out | 8  | Received byte |
| `rx_valid` | out | 1  | One-cycle high pulse when byte is received |

## Simulation

```bash
# Compile and run simulation
make sim

# Run simulation and open GTKWave
make wave

# Clean build artifacts
make clean
```

The testbench uses `CLK_FREQ=10_000_000` and `BAUD_RATE=1_000_000` for fast simulation. Connect TX loopback to RX and verify three bytes: `0xAB`, `0xCD`, `0xEF`.
