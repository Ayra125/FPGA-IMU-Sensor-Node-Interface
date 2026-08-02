# FPGA IMU Sensor Node Interface

> FPGA-based MPU6050 data-acquisition pipeline implemented in SystemVerilog on a Digilent Basys 3.

## Project Status

🚧 **In development**

Current phase: SystemVerilog fundamentals and architecture definition.

**2026-07-29:** Configured the local SystemVerilog toolchain in VS Code (syntax highlighting and linting against Icarus Verilog). Currently writing and simulating a small synchronous counter as a Phase 0 warm-up exercise before starting the sensor RTL.

**2026-08-02:** A Codex review of the counter practice exercise (`practice/counter/tb_counter.sv`) found the self-checking testbench could print a false `PASS` after a real mismatch, since only the last check controlled the verdict. Fixed by adding a persistent error counter fed by every check and a proper three-outcome verdict — then verified for real by fault-injecting a deliberate bug into a scratch copy of the counter and confirming the testbench correctly reported failure instead of a false pass. A follow-up review found the testbench still always exits with a successful process status regardless of pass/fail (needs `$fatal` on failure); that fix, plus the still-missing `$dumpfile`/`$dumpvars` waveform dump, are the next tasks. Phase 0 gate remains not passed.

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
