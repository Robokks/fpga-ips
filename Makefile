.PHONY: all sim-uart sim-spi sim-i2c clean

all: sim-uart sim-spi sim-i2c

sim-uart:
	$(MAKE) -C uart sim

sim-spi:
	$(MAKE) -C spi sim

sim-i2c:
	$(MAKE) -C i2c sim

clean:
	$(MAKE) -C uart clean
	$(MAKE) -C spi clean
	$(MAKE) -C i2c clean
