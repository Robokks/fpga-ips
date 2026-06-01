# Quadrature Encoder Decoder IP

Synthesizable SystemVerilog quadrature encoder decoder with ABZ interface, 4× resolution decoding, Z-index angle reset, and initial-angle preload. Compatible with NI LabVIEW FPGA (Vivado / Xilinx).

## Features

| Feature | Description |
|---------|-------------|
| **4× decoding** | Counts on every A and B edge — maximum resolution |
| **Input synchronizer** | 2-stage flip-flop chain; prevents metastability on async encoder inputs |
| **Debounce filter** | Configurable-length stable-count debounce; set to 0 for clean optical/magnetic encoders |
| **Z index reset** | Counter resets to `z_preset` on Z rising edge when `z_reset_en=1` |
| **Load initial angle** | Preload counter with any value via `load_en` / `init_angle` |
| **Direction output** | `dir=1` = CW/forward, `dir=0` = CCW/backward |
| **Error detection** | 1-cycle `error` pulse on illegal 2-bit simultaneous AB transition |
| **Initialized flag** | `initialized` latches high after first Z reset |

## Quadrature Encoding

Forward (CW) AB state sequence: `00 → 01 → 11 → 10 → 00 ...`

```
 A: ‾‾|__|‾‾|__|‾‾
 B: __|‾‾|__|‾‾|__
    ↑  ↑  ↑  ↑       4 counts per electrical cycle
 Z: ___________‾|_  one pulse per mechanical revolution
```

4× decode transition table:

| Transition | Direction |
|-----------|-----------|
| 00→01, 01→11, 11→10, 10→00 | +1 (CW) |
| 00→10, 10→11, 11→01, 01→00 | −1 (CCW) |
| 00→11, 11→00, 01→10, 10→01 | **Error** |

## Ports

### `quad_enc_top`

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | System clock |
| `rst_n` | in | 1 | Active-low async reset (clears angle to 0) |
| `a_in` | in | 1 | Raw channel A from encoder |
| `b_in` | in | 1 | Raw channel B from encoder |
| `z_in` | in | 1 | Raw Z/index channel from encoder |
| `z_reset_en` | in | 1 | 1 = reset counter on Z rising edge |
| `z_preset` | in | CNT_WIDTH | Value to load on Z pulse (usually 0) |
| `load_en` | in | 1 | Pulse high for 1 cycle to preload counter |
| `init_angle` | in | CNT_WIDTH | Value to load when `load_en` pulses |
| `angle` | out | CNT_WIDTH | Current position (unsigned, wraps on overflow) |
| `dir` | out | 1 | Last direction: 1=CW, 0=CCW |
| `z_pulse` | out | 1 | 1-cycle pulse on debounced Z rising edge |
| `error` | out | 1 | 1-cycle pulse on illegal AB transition |
| `initialized` | out | 1 | Latches 1 after first Z-reset (z_reset_en must be 1) |

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CNT_WIDTH` | 32 | Angle counter width in bits |
| `SYNC_STAGES` | 2 | Synchronizer depth (≥2; increase for noisy lines) |
| `DEBOUNCE_LEN` | 8 | Cycles input must be stable before accepted (0=disable) |

## Priority

When multiple events occur in the same clock cycle:

1. `rst_n` — asynchronous reset (highest)
2. `load_en` — synchronous preload
3. Z rising edge — index reset (if `z_reset_en=1`)
4. Quadrature count — normal operation

## Simulation

```bash
make sim      # compile + simulate
make wave     # open waveform in GTKWave
make clean    # remove build artifacts
```

Requires: `iverilog`, `gtkwave`

```bash
sudo apt-get install iverilog gtkwave
```

## LabVIEW FPGA Integration

This IP is designed for use as a **LabVIEW FPGA CLIP** (Component Level IP) on NI FlexRIO, cRIO, or myRIO targets (Xilinx Kintex-7 / Zynq).

### Clock recommendation

| NI Target | On-board clock | Suggested system clock |
|-----------|---------------|------------------------|
| NI 7972R/7975R (FlexRIO) | 200 MHz | 40–200 MHz |
| NI myRIO-1900 | 40 MHz | 40 MHz |
| NI cRIO-9063 | 40 MHz | 40 MHz |

### Debounce sizing

| Encoder type | `DEBOUNCE_LEN` @ 40 MHz |
|-------------|------------------------|
| Optical (clean signal) | 0–2 |
| Magnetic (Hall effect) | 4–10 |
| Mechanical (contact) | 1000–4000 (1–100 ms) |

### LabVIEW FPGA interface

Map ports to LabVIEW FPGA CLIP node:

```
CLIP clock input   → clk           (from LabVIEW FPGA clock domain)
CLIP Boolean       → rst_n         (from LabVIEW reset line, invert if needed)
CLIP Boolean input → a_in, b_in, z_in   (from FPGA I/O pins)
CLIP Boolean input → z_reset_en, load_en
CLIP U32 input     → z_preset, init_angle
CLIP U32 output    → angle
CLIP Boolean output→ dir, z_pulse, error, initialized
```

### Xilinx synthesis notes

- Uses only standard synchronous logic — no unintended latches
- `SYNC_STAGES=2` infers `(*ASYNC_REG="TRUE"*)` — add this attribute in XDC for CDC safety:
  ```
  set_property ASYNC_REG TRUE [get_cells {*a_sync_r_reg[*] *b_sync_r_reg[*] *z_sync_r_reg[*]}]
  ```
- DEBOUNCE counter adds registers only — no DSP or block RAM inferred
- Passes timing at 200 MHz on Kintex-7

## Testbench

`tb/quad_enc_tb.sv` runs **12 checks**:

| Test | Checks |
|------|--------|
| 1 | Reset → angle=0 |
| 2 | 8 forward steps → angle=8, dir=1 |
| 3 | Z pulse → angle resets to 0, initialized=1 |
| 4 | 12 more forward steps → angle=12 |
| 5 | 4 backward steps → angle=8, dir=0 |
| 6 | Load angle=100 → angle=100 |
| 7 | 1 forward step → angle=101 |
| 8 | Illegal AB transition → error pulse |
| 9 | z_reset_en=0 → Z fires z_pulse but angle unchanged |
