# FPGA IMU Sensor Node Interface

> In-development FPGA MPU6050 data-acquisition pipeline targeting SystemVerilog on a Digilent Basys 3.

## Project Status

🚧 **In development**

**Current phase:** Phase 1 — Freeze the Specification and Phase 2 — I2C Engine are complete at the application-milestone gate. Phase 3 — MPU6050 Model and Acquisition Controller is active.

The Phase 2 timing-enable generator and generic I2C engine pass their self-checking simulations, including the documented normal, NACK, timeout, clock-stretch, reset, repeated-START, and backpressure cases. Phase 3 implementation is now underway: the behavioral MPU6050 model scaffold and engine-to-model testbench wiring compile, while the transaction stimulus, behavioral regression, acquisition controller, synthesis, and hardware demonstration remain incomplete.

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

### Phase 2 — Generic I2C Engine (simulation complete)

**2026-08-11:** Completed the first Phase 2 increment: `rtl/i2c/timing_enable_gen.sv` produces one-cycle `i2c_step` and `sample_tick` enables from the 100 MHz system clock without generating a second fabric clock. Defaults target 100 kHz I2C timing (`i2c_step` every 500 system-clock cycles) and a 100 Hz acquisition cadence (`sample_tick` every 1,000,000 cycles).

Its learner-authored self-checking testbench, `tb/i2c/tb_timing_enable_gen.sv`, overrides the parameters to 4 and 10 cycles for fast simulation. It checks pulse cadence, one-cycle pulse deassertion, and synchronous reset before and after normal activity. Icarus Verilog completed the regression with `Pass no errors found` and exit status zero. This is simulation evidence only; no synthesis, timing, or hardware result is claimed.

**Completed 2026-08-22:** Phase 2 produced a reusable, MPU6050-independent I2C bit/byte engine and timing-enable generator. The design remains in the 100 MHz system-clock domain and uses one-cycle enables for protocol timing rather than creating a fabric-derived clock.

The engine implements:

- A request/ready command interface for `START`, `STOP`, `WRITE_BYTE`, and `READ_BYTE`
- Open-drain SDA/SCL control and two-flop synchronization of the observed bus inputs
- START, repeated START, STOP, MSB-first transmit and receive, and slave/master ACK or NACK behavior
- Clock-stretch waiting and a bounded 500,000-system-clock-cycle timeout (5 ms at 100 MHz)
- Defined reset, backpressure, completion, NACK-error, and timeout-error behavior

Verification uses a learner-authored, self-checking SystemVerilog testbench with an inline behavioral I2C slave. The regression covers directed protocol sequences, boundary byte patterns, seeded-random writes and reads, temporary and over-timeout clock stretching, reset during active transfers, repeated START, write NACK, read ACK/final NACK, and back-to-back commands under backpressure. Six continuous monitors check bus data stability, known open-drain controls, one terminal result per accepted command, bounded completion, reset cleanup, and command-field stability. Scratch fault injection was used while developing the monitors to confirm that each one detects its intended failure rather than merely passing the correct RTL.

Simulation-driven debugging exposed both design and verification issues, including incorrect SCL phase sequencing, a timeout counted in the wrong units, command acceptance that could miss a one-cycle request, model-side bus-release leaks, and race-prone read-bit setup. The fixes were retained with regression cases. The final testbench measures complete 5 us SCL high and low phases for byte transfers, corresponding to the specified 100 kHz bus rate in simulation.

#### Why Phase 2 matters to FPGA/RTL recruiters

Phase 2 is the first substantial protocol block in the project. It gives reviewers concrete evidence of finite-state-machine design, synchronous timing control, open-drain bus modeling, handshake and backpressure semantics, input synchronization, bounded error recovery, and protocol-aware verification. Just as important, the bug history shows an evidence-based workflow: failures were reproduced, traced to a specific timing or ownership problem, fixed, and protected by a regression check. Those are directly relevant habits for entry-level RTL design and design-verification work.

Regression command:

```bash
iverilog -g2012 -Wall -o /tmp/i2c_engine.vvp rtl/i2c/timing_enable_gen.sv rtl/i2c/i2c_engine.sv tb/i2c/tb_i2c_engine.sv && vvp /tmp/i2c_engine.vvp
```

The recorded Phase 2 run prints the reproducible random seed, ends with `PASS: no errors found`, and exits with status zero.

**Evidence boundary:** Phase 2 is verified by simulation. The I2C engine has not yet been synthesized, checked for post-implementation timing, measured for resource use, or validated with the physical MPU6050. Those results belong to later project phases.

### Phase 3 — MPU6050 behavioral model (in progress)

**2026-08-26:** Started the Phase 3 behavioral MPU6050 model and connected it to the existing I2C engine in `tb/mpu6050/tb_mpu6050_model.sv`. The model currently contains a small byte-addressed register map, deterministic test values at `0x3B` and `0x3C`, START/STOP detection, receive-byte assembly, device-address and register-pointer tracking, ACK handling, and an initial read-data path. The testbench includes the simulation clock, timing-enable generator, I2C engine, shared open-drain SDA/SCL buses, and model instance.

The current model/testbench files compile with Icarus Verilog, but no Phase 3 runtime PASS is claimed yet. The testbench still needs self-checking stimulus for `START → D2 → 3B → STOP`, followed by the repeated-START and two-byte read sequence. The model’s ACK/data phase behavior must be validated in simulation before extending it to initialization, the full 14-byte burst, and the acquisition controller.

Compile command for the current Phase 3 scaffold:

```bash
iverilog -g2012 -Wall -s tb_mpu6050_model -o /tmp/tb_mpu6050_model.vvp rtl/i2c/timing_enable_gen.sv rtl/i2c/i2c_engine.sv tb/mpu6050/mpu6050_model.sv tb/mpu6050/tb_mpu6050_model.sv
```

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
