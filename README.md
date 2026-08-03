# FPGA IMU Sensor Node Interface

> FPGA-based MPU6050 data-acquisition pipeline implemented in SystemVerilog on a Digilent Basys 3.

## Project Status

🚧 **In development**

Current phase: SystemVerilog fundamentals and architecture definition.

**2026-07-29:** Configured the local SystemVerilog toolchain in VS Code (syntax highlighting and linting against Icarus Verilog). Currently writing and simulating a small synchronous counter as a Phase 0 warm-up exercise before starting the sensor RTL.

**2026-08-02:** Hardened the counter practice testbench (`practice/counter/tb_counter.sv`) against three separate defects, each found by review and each confirmed fixed by fault injection rather than assumption:

- **False `PASS` after a real failure.** Only the final wraparound check controlled the verdict, so mismatches caught earlier by the cycle-by-cycle scoreboard were discarded. Fixed with a persistent error counter fed by every check, plus a three-outcome verdict (wraparound failed / clean pass / wraparound correct but earlier mismatch).
- **Successful exit status on a failing run.** The testbench always ended via `$finish`, which reports success to the shell regardless of what was printed — meaning an automated regression could not distinguish pass from fail. Now ends via `$fatal` when the error counter is nonzero.
- **Silent overflow of the error counter itself.** The counter was declared `logic [3:0]`, so it wrapped at 16 and under-reported; a run with exactly 16 failures would have wrapped to zero and reported a clean pass. Changed to `int`.

Verification method: a deliberately faulty copy of the counter (incrementing by 2) was simulated against the real testbench. It now reports all 21 mismatches and exits `1`; before these fixes the same run printed `PASS` and exited `0`.

Also added `$dumpfile`/`$dumpvars` and inspected the first waveform of the project in Surfer, confirming reset behavior, enabled increment, disabled hold, and 15-to-0 wraparound against the RTL.

Phase 0 gate remains not passed — the two-state FSM, the HDLBits exercises, and selecting a supported x86-64 Vivado host are still outstanding.

Hardware verification has not yet been completed. All performance and resource results will be added after synthesis and physical testing.

## Overview

This project implements a complete FPGA interface for acquiring motion data from an MPU6050 inertial measurement unit.

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
- **Simulation:** Vivado Simulator
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
