# SPI IP Core

Synthesizable SPI Master and Slave IP cores written in SystemVerilog.

## Features

- **SPI Mode 0** (CPOL=0, CPHA=0) — configurable via parameters
- **8-bit transfers**, MSB first
- **Clock divider** — SCLK = `clk / (2 × CLK_DIV)`, parameterizable
- **Loopback top-level** (`spi_top`) connects master and slave for easy testing
- No external FIFO required — single-byte handshake
- Fully synthesizable (no `#delays` in RTL)

## Modules

### `spi_master`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `start` | in | 1 | Pulse high for 1 cycle to begin transfer |
| `mosi_data` | in | 8 | Byte to transmit |
| `miso_data` | out | 8 | Byte received from slave |
| `done` | out | 1 | 1-cycle pulse when transfer complete |
| `busy` | out | 1 | High during transfer |
| `sclk` | out | 1 | SPI clock |
| `mosi` | out | 1 | Master-out / Slave-in |
| `miso` | in | 1 | Master-in / Slave-out |
| `cs_n` | out | 1 | Chip select (active-low) |

**Parameters:** `CLK_DIV` (default 4), `CPOL` (default 0), `CPHA` (default 0)

### `spi_slave`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `sclk` | in | 1 | SPI clock from master |
| `mosi` | in | 1 | Data from master |
| `miso` | out | 1 | Data to master |
| `cs_n` | in | 1 | Chip select (active-low) |
| `rx_data` | out | 8 | Received byte |
| `rx_valid` | out | 1 | 1-cycle pulse when byte received |
| `tx_data` | in | 8 | Byte to send back to master |

**Parameters:** `CPOL` (default 0), `CPHA` (default 0)

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

The testbench (`tb/spi_tb.sv`) instantiates `spi_top` (master ↔ slave loopback) and:
1. Sends 3 bytes from master: `0xA5`, `0x3C`, `0xF0`
2. Verifies slave receives each byte correctly
3. Prints `[PASS]` / `[FAIL]` per transfer and a summary

Simulation parameters: `CLK_DIV=2` (fast sim, 100 MHz clock)
