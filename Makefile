.PHONY: all sim-uart sim-spi sim-i2c sim-quad_enc clean

all: sim-uart sim-spi sim-i2c sim-quad_enc

sim-uart:
	$(MAKE) -C uart sim

sim-spi:
	$(MAKE) -C spi sim

sim-i2c:
	$(MAKE) -C i2c sim

sim-quad_enc:
	$(MAKE) -C quad_enc sim

clean:
	$(MAKE) -C uart clean
	$(MAKE) -C spi clean
	$(MAKE) -C i2c clean
	$(MAKE) -C quad_enc clean
