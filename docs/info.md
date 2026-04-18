## How it works

FinSec-1 (`tt_um_fp_id`) is a hardware-only AS-68M/AS-68ML fingerprint verification ASIC.
It implements the complete AS-68M UART command protocol (57600 baud, 8-N-1) as a
**14-state deterministic FSM** in synthesisable Verilog RTL — with no microcontroller,
no FPGA, and no CPU in the trusted execution path.

### Architecture

Four Verilog modules:

- `tt_um_fp_id` — Tiny Tapeout wrapper with CDC double-flip-flop synchronisers on
  `fp_touch` (ui_in[1]) and `uart_rx` (ui_in[0])
- `verify_ctrl` — 14-state Mealy/Moore FSM executing the full AS-68M command sequence
- `uart_tx` — 57600 baud 8-N-1 UART transmitter (50 MHz clock, 868 cycles/bit)
- `uart_rx` — 57600 baud 8-N-1 UART receiver with 2-FF metastability synchroniser

### FSM Command Sequence (autonomous, no CPU)

1. **VfyPwd** — Authenticate sensor (password 0x00000000)
2. **SetSysPara** — Set security level to 1
3. **GetImg** — Capture fingerprint image
4. **Img2Tz** — Convert image to feature vector (buffer 1)
5. **Search** — 1:N search across 100 enrolled templates (IDs 0–99)

On a verified match (`conf = 0x00`), `uo_out[1]` (MATCH_OUT) asserts HIGH for 3 seconds.

### Pin Mapping

| Pin | Signal | Description |
|-----|--------|-------------|
| ui_in[0] | uart_rx | UART data from sensor TD pin 4 (57600 baud) |
| ui_in[1] | fp_touch | Finger-present from sensor ST pin 2 |
| uo_out[0] | uart_tx | UART command output to sensor RD pin 5 |
| uo_out[1] | match_out | HIGH 3s on verified fingerprint match |
| uo_out[2] | no_match | HIGH 3s when finger not enrolled |
| uo_out[3] | error_out | HIGH on timeout or protocol error |
| uo_out[4] | sensor_rdy | HIGH after VfyPwd ACK received |
| uo_out[5] | finger_det | Synchronised fp_touch output |
| uo_out[6] | uart_busy | HIGH during UART transmission |
| uo_out[7] | heartbeat | ~1.5 Hz toggle — ASIC alive indicator |

All `uio` pins are unused; `uio_oe = 0x00`.

### Post-Layout Results (LibreLane 2.4.2, SKY130B)

| Metric | Value |
|--------|-------|
| Die area | 41,875.4 µm² |
| Core utilisation | 51.15% |
| Standard cells | 1,936 |
| DRC violations (Magic + KLayout) | 0 |
| LVS errors | 0 |
| Antenna violations | 0 |
| Setup violations (9 PVT corners) | 0 |
| Hold violations (9 PVT corners) | 0 |
| Total power (1.8 V, 50 MHz) | 1.153 mW |

## How to test

### Required hardware

- AS-68M or AS-68ML capacitive fingerprint sensor (SYNOCHIP)
- 3.3 V supply (AMS1117-3.3 from 5 V recommended)
- 50 MHz clock input (or 25 MHz TT demo board clock — update `CLK_FREQ` parameter)
- 10 kΩ pull-up + 100 nF on RST_N
- AO3401 P-MOSFET + 10 kΩ gate resistor on uo_out[1]
- 330 Ω LEDs on uo_out[1:4] for status indication

### Wiring

1. Sensor TD (pin 4) → ui_in[0]
2. Sensor ST (pin 2) → ui_in[1]
3. uo_out[0] → sensor RD (pin 5)
4. uo_out[1] → AO3401 gate via 10 kΩ

### Test procedure

**Prerequisite:** Pre-enroll at least one fingerprint into the sensor flash using
a separate host enrollment tool before testing the ASIC.

1. Apply 3.3 V and release reset (RST_N HIGH).
2. Wait ~800 ms — `uo_out[4]` (sensor_rdy) goes HIGH once VfyPwd ACK is received.
3. Confirm `uo_out[7]` (heartbeat) is toggling at ~1.5 Hz.
4. Place an **enrolled** finger: `uo_out[1]` goes HIGH for 3 s.
5. Place an **unenrolled** finger: `uo_out[2]` goes HIGH for 3 s.
6. If `uo_out[3]` latches HIGH (error), toggle RST_N to clear.

### Simulation

```bash
cd test && make
```

Three cocotb testbenches: `test_reset`, `test_heartbeat`, `test_uart_idle`.
All pass with cocotb 2.0.1 and Icarus Verilog 12.0.
