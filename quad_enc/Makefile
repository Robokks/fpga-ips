# Quadrature Encoder Decoder Makefile
TOP = quad_enc_tb
SRC = rtl/quad_enc_top.sv
TB  = tb/quad_enc_tb.sv
VCD = quad_enc_sim.vcd
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
