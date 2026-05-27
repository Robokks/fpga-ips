# UART IP Makefile
TOP = uart_tb
SRC = rtl/uart_tx.sv rtl/uart_rx.sv rtl/uart_top.sv
TB  = tb/uart_tb.sv
VCD = uart_sim.vcd
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
