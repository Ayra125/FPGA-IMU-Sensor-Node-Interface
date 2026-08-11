# FPGA IMU Sensor Node Interface

> In-development FPGA MPU6050 data-acquisition pipeline targeting SystemVerilog on a Digilent Basys 3.

## Project Status

🚧 **In development**

**Current phase:** Phase 1 — Freeze the Specification is complete at the shortened application-milestone gate. Phase 2 — I2C Engine is active.

The Phase 2 timing-enable generator and its self-checking testbench pass simulation. The generic I2C engine, its behavioral bus model, final-project synthesis, and MPU6050 hardware demonstration remain incomplete.

### Phase 0 — Tools and Fundamentals (complete)

**2026-07-29:** Configured the local SystemVerilog toolchain in VS Code (syntax highlighting and linting against Icarus Verilog). Currently writing and simulating a small synchronous counter as a Phase 0 warm-up exercise before starting the sensor RTL.

**2026-08-02:** Hardened the counter practice testbench (`practice/counter/tb_counter.sv`) against three separate defects, each found by review and each confirmed fixed by fault injection rather than assumption:

- **False `PASS` after a real failure.** Only the final wraparound check controlled the verdict, so mismatches caught earlier by the cycle-by-cycle scoreboard were discarded. Fixed with a persistent error counter fed by every check, plus a three-outcome verdict (wraparound failed / clean pass / wraparound correct but earlier mismatch).
- **Successful exit status on a failing run.** The testbench always ended via `$finish`, which reports success to the shell regardless of what was printed — meaning an automated regression could not distinguish pass from fail. Now ends via `$fatal` when the error counter is nonzero.
- **Silent overflow of the error counter itself.** The counter was declared `logic [3:0]`, so it wrapped at 16 and under-reported; a run with exactly 16 failures would have wrapped to zero and reported a clean pass. Changed to `int`.

Verification method: a deliberately faulty copy of the counter (incrementing by 2) was simulated against the real testbench. It now reports all 21 mismatches and exits `1`; before these fixes the same run printed `PASS` and exited `0`.

Also added `$dumpfile`/`$dumpvars` and inspected the first waveform of the project in Surfer, confirming reset behavior, enabled increment, disabled hold, and 15-to-0 wraparound against the RTL.

**2026-08-06:** Completed the remaining Phase 0 gate: ten relevant HDLBits exercises, a learner-authored two-state FSM with a self-checking testbench and waveform review, and a supported Vivado-to-Basys-3 flow. A minimal LED design was synthesized, implemented, converted to a bitstream, programmed over JTAG, and observed on physical LD0. This checkpoint validates the tool and board path only; it does not validate the MPU6050 design.

### Phase 1 — Freeze the Specification (application-milestone scope complete)

**2026-08-10:** Completed the shortened Phase 1 gate recorded in the Obsidian project notes. The completed specification work includes:

- A sensor-to-laptop block diagram covering reset conditioning, timing enables, generic I2C, MPU6050 control, packetization, FIFO buffering, packet serialization, and UART.
- One 100 MHz system-clock domain with clock-enable pulses rather than generated fabric clocks.
- An active-high synchronous internal-reset policy and documented asynchronous-input synchronization strategy.
- A 100 kHz I2C target, open-drain SDA/SCL behavior, START, repeated START, STOP, byte transmit/receive, ACK/NACK, clock-stretch waiting, and a bounded 5 ms command timeout.
- A request/ready command interface with terminal `done` or `error` results.
- Twelve essential I2C verification requirements covering normal read/write, ACK/NACK, START/STOP, repeated START, timeout, reset, data stability, command backpressure, and representative byte patterns.
- Six planned I2C safety/completion assertions and an explicit self-checking PASS/FAIL policy.
- A planned Icarus command for `rtl/i2c_engine.sv` and `tb/tb_i2c_engine.sv`. It is intentionally unrun because those Phase 2 files do not exist yet.
- A version-1 224-bit internal sample packet, 16-packet synchronous FIFO, 115,200-baud UART, and a 30-byte application-milestone wire frame consisting of a two-byte synchronization header plus the 28-byte payload.

The shortened gate intentionally defers project-wide traceability, CI, coverage closure, formal/UVM work, CRC, estimated-power analysis, and stretch features until after the first verified hardware pipeline.

### Next: Phase 2 — I2C Engine

**2026-08-11:** Completed the first Phase 2 increment: `rtl/i2c/timing_enable_gen.sv` produces one-cycle `i2c_step` and `sample_tick` enables from the 100 MHz system clock without generating a second fabric clock. Defaults target 100 kHz I2C timing (`i2c_step` every 500 system-clock cycles) and a 100 Hz acquisition cadence (`sample_tick` every 1,000,000 cycles).

Its learner-authored self-checking testbench, `tb/i2c/tb_timing_enable_gen.sv`, overrides the parameters to 4 and 10 cycles for fast simulation. It checks pulse cadence, one-cycle pulse deassertion, and synchronous reset before and after normal activity. Icarus Verilog completed the regression with `Pass no errors found` and exit status zero. This is simulation evidence only; no synthesis, timing, or hardware result is claimed.

Next, implement the generic I2C engine's documented idle open-drain behavior, then verify START generation before adding byte transfers, ACK/NACK handling, reads, repeated START, and timeout recovery.

Hardware verification has not yet been completed. All performance and resource results will be added after synthesis and physical testing.

## Overview

This project is building a complete FPGA interface for acquiring motion data from an MPU6050 inertial measurement unit.

The FPGA will:

- Configure the MPU6050 over I²C
- Read accelerometer, temperature, and gyroscope measurements
- Reconstruct signed 16-bit sensor values
- Timestamp each sample
- Buffer samples in a synchronous FIFO
- Package the measurements into a documented binary format
- Transmit packets to a laptop over UART
- Detect and report communication and buffer errors

The project focuses on synthesizable RTL design, protocol implementation, verification, timing analysis, and physical FPGA bring-up.

## Hardware and Tools

- **FPGA board:** Digilent Basys 3
- **FPGA:** AMD Artix-7 `xc7a35tcpg236-1`
- **Sensor:** MPU6050 IMU
- **Language:** SystemVerilog
- **Development environment:** AMD Vivado
- **Simulation:** Icarus Verilog for local self-checking tests; Vivado Simulator where vendor-tool testing is useful
- **Waveforms:** Surfer
- **Hardware debugging:** Vivado Integrated Logic Analyzer
- **Host connection:** Basys 3 USB-UART interface

## Scripted Setup

Scripted project creation will eventually be available with:

```bash
vivado -mode batch -source scripts/create_project.tcl
```

## System Architecture

```text
                     FPGA IMU Sensor Node

 MPU6050
+---------+      +-------------+      +------------------+
| Accel   | I²C  | I²C Master  |      | MPU6050          |
| Gyro    |<---->| Controller  |<---->| Acquisition FSM  |
| Temp    |      +-------------+      +--------+---------+
+---------+                                      |
                                                 v
                                        +----------------+
                                        | Timestamp and  |
                                        | Packetizer     |
                                        +--------+-------+
                                                 |
                                                 v
                                        +----------------+
                                        | Synchronous    |
                                        | FIFO           |
                                        +--------+-------+
                                                 |
                                                 v
                                        +----------------+
                                        | UART           |
                                        | Transmitter    |
                                        +--------+-------+
                                                 |
                                                 v
                                             Laptop
```
