# FPGA IP Library

A collection of reusable, synthesizable FPGA IP cores written in SystemVerilog. All IPs are self-contained, parameterizable, and verified with Icarus Verilog simulation.

## Available IPs

| IP | Description |
|----|-------------|
| **UART** | Universal Asynchronous Receiver/Transmitter — configurable baud rate, 8N1, full duplex, FIFO-less |
| **SPI**  | Serial Peripheral Interface — master and slave cores, configurable CPOL/CPHA, 8-bit transfers |
| **I2C**  | Inter-Integrated Circuit — master and slave cores, 7-bit addressing, standard/fast mode |

## Prerequisites

- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`) — version 11+ recommended
- [GTKWave](http://gtkwave.sourceforge.net/) (`gtkwave`) — for waveform viewing (optional)

Install on Ubuntu/Debian:
```bash
sudo apt-get install iverilog gtkwave
```

## Simulating

### Simulate all IPs
```bash
make all
```

### Simulate a specific IP
```bash
make sim-uart
make sim-spi
make sim-i2c
```

### Simulate with waveform viewer
```bash
cd uart && make wave
cd spi  && make wave
cd i2c  && make wave
```

### Clean build artifacts
```bash
make clean
```

See each IP's own `README.md` and `Makefile` for detailed usage.

## Directory Structure

```
fpga-ips/
├── Makefile              # Top-level convenience targets
├── README.md             # This file
├── .gitignore
│
├── uart/
│   ├── README.md
│   ├── Makefile
│   ├── rtl/
│   │   ├── uart_top.sv   # Top-level: instantiates TX + RX
│   │   ├── uart_tx.sv    # UART transmitter FSM
│   │   └── uart_rx.sv    # UART receiver FSM
│   └── tb/
│       └── uart_tb.sv    # Loopback testbench
│
├── spi/
│   ├── README.md
│   ├── Makefile
│   ├── rtl/
│   │   ├── spi_top.sv    # Top-level loopback: master ↔ slave
│   │   ├── spi_master.sv # SPI master with clock divider
│   │   └── spi_slave.sv  # SPI slave
│   └── tb/
│       └── spi_tb.sv     # SPI loopback testbench
│
└── i2c/
    ├── README.md
    ├── Makefile
    ├── rtl/
    │   ├── i2c_top.sv    # Top-level loopback: master ↔ slave
    │   ├── i2c_master.sv # I2C master with open-drain model
    │   └── i2c_slave.sv  # I2C slave with address matching
    └── tb/
        └── i2c_tb.sv     # I2C write/read testbench
```

## License

MIT License — see individual IP directories for details.
