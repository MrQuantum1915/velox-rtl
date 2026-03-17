# velox-rtl

Real-time object speed detection on the Nexys A7 FPGA.

IR sensors feed a 4-stage pipelined datapath; capture, measure, compute, display; with FSM-based control, fixed-point arithmetic, and live 7-segment output. Built in RTL Verilog and deployed on Nexys A7
AMD Artix™ 7 FPGA; using [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html) . 

[Nexys A7 | Reference](https://digilent.com/reference/programmable-logic/nexys-a7/reference-manual)

---

## Details

**velox-rtl** measures the speed of a physical object passing through an IR sensor gate. Two operating modes are supported:

- **Linear mode**: two IR sensors spaced a fixed distance apart. A timer starts on the first trigger and stops on the second. Speed is computed as: $$v = \frac{d}{\Delta{t}}$$
- **Rotational mode**: a single IR sensor facing a slotted or reflective wheel. Pulses are counted over a 1 second window and converted to RPM.

The system is fully pipelined: while one object's speed is being computed (stage 3), the next object's pulse interval is still being measured (stage 2). Multiple objects can be in-flight through the pipeline simultaneously.

Pipelining might seem uneccessary because Nexys operates at 100 MHz clock frequency; and physical objects breaking an IR beam operate on a timescale of milliseconds. A simple seqeuntial FSM would have been more than sufficient. Anyways its a good exercise for implementing pipelining in digital design :)

---

## Hardware

| Component | Detail |
|-----------|--------|
| FPGA Board | Digilent Nexys A7 (AMD Artix-7 XC7A100T) |
| Clock | 100 MHz onboard oscillator |
| Sensors | IR break-beam or reflective sensors (2× for linear, 1× for rotational) |
| Input | SW[0] — mode select · SW[1] — unit select (m/s vs km/h) |
| Output | 8-digit 7-segment display · LED[15:0] status indicators |

---

## Architecture

```
IR Sensor(s)
     │
     ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  S1 Capture │->R->│ S2 Measure  │->R->│ S3 Compute  │->R->│ S4 Display  │
│  2-FF sync  │     │ Timer / cnt │     │ Fixed-point │     │ Bin -> BCD  │
│  Edge detect│     │ Window latch│     │ div Q16.8   │     │ 7-seg mux   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                         │                  ▲
                         ▼                  │
                  ┌─────────────────────────────────────┐
                  │        FSM — Control Path           │
                  │  IDLE->ARMED->MEASURING->COMPUTING  │
                  │  ->DISPLAYING->IDLE                 │
                  └─────────────────────────────────────┘
                         │
                         ▼
                  ┌─────────────────────────────────┐
                  │           Datapath              │
                  │  timer_reg · pulse_cnt          │
                  │  elapsed_reg · quotient_reg     │
                  │  remainder_reg · bcd_reg        │
                  └─────────────────────────────────┘
```

### Pipeline stages

| Stage | Module | Function |
|-------|--------|----------|
| S1: Capture | `input_capture.v` | Two-stage synchronizer + rising-edge pulse generator. Eliminates metastability on async IR inputs. |
| S2: Measure | `measurement.v` | Linear: timestamps Δt between two sensor edges. Rotational: counts pulses in a 1-second window using a clock-divided strobe. |
| S3: Compute | `speed_compute.v` | Iterative restoring divider in Q16.8 fixed-point format. Scales result to m/s or km/h based on SW[1]. |
| S4: Display | `seg7_display.v` | Binary-to-BCD conversion (double dabble algorithm), 8-digit 7-segment multiplexed at 500 Hz. |

Metastability issue: The IR sensor signal is async with respect to clock of Nexys FGPA. When FPGA tries to read that signal, it might catch it right in the middle of a transition (neither 0 nor 1 yet). The flip-flop doesn't know what value to latch and can output garbage for an unpredictable amount of time. 

The fix is **2-FF synchronizer**: passing the signal through two flip-flops in series before using it. By the time it exits the second FF, it has had two clock cycles to settle into a clean 0 or 1.

### FSM states

```
IDLE ──(sensor armed)──► ARMED ──(first trigger)──► MEASURING
                                                          │
                                          (second trigger / window end)
                                                          ▼
                                                     COMPUTING
                                                          │
                                                 (divider done)
                                                          ▼
                                                     DISPLAYING ──► IDLE
```

### Fixed-point arithmetic

Nexys A7 has NO floating-point unit. Division $\frac{d}{\Delta{t}}$ is implemented as an iterative restoring divider operating on Q16.8 numbers (16-bit integer part, 8-bit fractional). This gives speed resolution to 2 decimal places without a soft-core processor or FPU.

```
Q16.8 example:
  speed = 3.75 m/s -> stored as 0x0003C0  (3 << 8 | 0.75 × 256 = 192)
```

---

## Module Structure

```
velox-rtl/
├── src/
│   ├── top.v               # Top-level, I/O mapping
│   ├── input_capture.v     # S1: synchronizer + edge detector
│   ├── measurement.v       # S2: timer / pulse counter
│   ├── speed_compute.v     # S3: fixed-point divider + scaler
│   ├── seg7_display.v      # S4: BCD + 7-segment mux
│   ├── fsm_control.v       # FSM control path
│   ├── datapath.v          # Datapath registers and muxes
│   ├── clock_divider.v     # 100 MHz -> 1 Hz window strobe
│   └── debouncer.v         # Switch input debouncer
├── constraints/
│   └── velox-rtl.xdc      # Nexys A7 pin assignments
├── sim/
│   └── tb_top.v            # Top-level testbench
└── README.md
```

---

## Pin Assignments (Nexys A7)

| Signal | Pin | Function |
|--------|-----|----------|
| `clk` | E3 | 100 MHz system clock |
| `ir_sensor[0]` | PMOD JA[0] | First IR sensor |
| `ir_sensor[1]` | PMOD JA[1] | Second IR sensor (linear mode) |
| `sw[0]` | J15 | Mode select (0=linear, 1=rotational) |
| `sw[1]` | L16 | Unit select (0=m/s, 1=km/h) |
| `btnc` | N17 | System reset |
| `seg_an[7:0]` | — | 7-segment anodes (active low) |
| `seg_cat[6:0]` | — | 7-segment cathodes (active low) |
| `led[15:0]` | — | Status LEDs |

> Full pin assignments in `constraints/velox-rtl.xdc`.

---

## LED Status Map

| LED | Meaning |
|-----|---------|
| `LED[0]` | Sensor 0 active |
| `LED[1]` | Sensor 1 active |
| `LED[3:2]` | FSM state (binary) |
| `LED[4]` | Mode (0=linear, 1=RPM) |
| `LED[5]` | Unit (0=m/s, 1=km/h) |
| `LED[6]` | Divider busy |
| `LED[7]` | New result ready |

---

## 7-Segment Display Layout

```
[ RPM / m/s ]  [ _ _ _ . _ _ ]  [ mode ]
  digit[7]      digits[6:1]      digit[0]
```

- Digits 6–1: speed value with decimal point at digit 3
- Digit 7: unit glyph (`r` = RPM, `S` = m/s, `C` = km/h)
- Digit 0: mode indicator (`L` = linear, `o` = rotational)

---

## Build

### Requirements

- Xilinx Vivado 2022.x or later
- Nexys A7 board
- IR sensor module(s) with 3.3V logic output

### Synthesize and program

```bash
git clone https://github.com/<your-username>/velox-rtl.git
cd velox-rtl

# open in vivado (GUI)
vivado -source scripts/build.tcl

# or add sources manually in Vivado:
# 1. create project targeting xc7a100tcsg324-1
# 2. add all src/*.v files
# 3. add constraints/velox-rtl.xdc
# 4. run Synthesis -> implementation -> generate Bitstream
# 5. program device
```

---

## Computer Architecture Concepts

| Concept | Where |
|---------|-------|
| Pipelining | 4-stage pipeline with inter-stage registers |
| Datapath / Control separation | `datapath.v` + `fsm_control.v` |
| Hazard handling | Pipeline stall on divider multi-cycle latency |
| Fixed-point arithmetic | Q16.8 restoring divider in `speed_compute.v` |
| Metastability mitigation | 2-FF synchronizer in `input_capture.v` |
| Clock domain management | `clock_divider.v` for RPM window strobe |

Clocl domain issue: For RPM mode we need to count pulses over exactly 1 second. So build a counter that counts up to 100,000,000 and resets. That generates a single 1 cycle pulse every second = 1 second window boundary. 

$\therefore$ deriving a slower timing signal from the main clock.

---

## License

Distributed under the GNU General Public License v3. See [`LICENSE`](LICENSE) for more information.