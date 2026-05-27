# SPI IP Makefile
TOP = spi_tb
SRC = rtl/spi_master.sv rtl/spi_slave.sv rtl/spi_top.sv
TB  = tb/spi_tb.sv
VCD = spi_sim.vcd
VVP = $(TOP).vvp

.PHONY: sim wave clean

sim: $(VVP)
	vvp $(VVP)

$(VVP): $(SRC) $(TB)
	iverilog -g2012 -o $(VVP) $(TB) $(SRC)

wave: sim
	gtkwave $(VCD) &

clean:
	rm -f $(VVP) $(VCD) *.log
