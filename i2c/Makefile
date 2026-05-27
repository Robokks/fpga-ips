# I2C IP Makefile
TOP = i2c_tb
SRC = rtl/i2c_master.sv rtl/i2c_slave.sv rtl/i2c_top.sv
TB  = tb/i2c_tb.sv
VCD = i2c_sim.vcd
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
