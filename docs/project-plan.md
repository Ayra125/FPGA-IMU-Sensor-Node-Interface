---
title: FPGA IMU Sensor Node Interface
status: starting
started: 2026-07-24
target_completion: 2026-09-30
target_board: Digilent Basys 3
primary_language: SystemVerilog
---

# FPGA IMU Sensor Node Interface

## What this project is

This project is a complete FPGA data-acquisition pipeline for an MPU6050 inertial measurement unit. The Basys 3 FPGA will configure and read the sensor over I2C, reconstruct accelerometer and gyroscope samples, timestamp and buffer them, and transmit them to a laptop over UART.

The important artifact is not simply an I2C controller. It is a complete RTL and verification story:

> A synthesizable sensor interface, acquisition state machine, packet datapath, FIFO, and UART output verified with a self-checking SystemVerilog environment and demonstrated on an Artix-7 FPGA.

This extends the earlier STM32 project without repeating it. The STM32 project demonstrates controlling the MPU6050 with firmware; this project demonstrates designing the controller and data pipeline as digital hardware.

## Why this project matters

The project is intended to create evidence for FPGA, RTL design, design verification, front-end ASIC/SoC, and memory-controller internships. It should demonstrate:

- Synthesizable SystemVerilog.
- Finite-state-machine design.
- Cycle-accurate protocol reasoning.
- I2C open-drain signaling, ACK/NACK handling, and timeouts.
- Parameterized FIFO design and backpressure.
- Timestamping and packet formatting.
- Self-checking testbenches, scoreboards, assertions, and functional coverage.
- Vivado synthesis, implementation, timing analysis, and resource reporting.
- Hardware bring-up and waveform-based debugging.

This project does not claim transistor-level memory design, physical design, tape-out experience, or hardware behavior that has not been measured.

## Required MVP architecture

The minimum complete system contains these blocks:

1. **Clock, reset, and timing generation**
   - Synchronous reset behavior is documented.
   - A configurable divider produces the I2C timing enable.
   - The design does not create an uncontrolled fabric clock.

2. **I2C bit/byte engine**
   - START, repeated START, STOP, byte transmit, and byte receive.
   - ACK/NACK generation and detection.
   - Open-drain SDA behavior.
   - Clock-stretch and transaction timeout handling.

3. **MPU6050 acquisition controller**
   - Wakes and configures the sensor from its register map.
   - Reads the 14-byte accelerometer, temperature, and gyroscope frame.
   - Reconstructs signed 16-bit values in the correct byte order.
   - Reports communication failures instead of silently using stale data.

4. **Timestamp and packetizer**
   - Adds a cycle or sample counter.
   - Produces a documented fixed-width internal sample packet.
   - Records error, overflow, or dropped-sample status.

5. **Parameterized synchronous FIFO**
   - Configurable width and depth.
   - Full, empty, almost-full, overflow, and underflow status.
   - A valid/ready-style interface or another clearly documented handshake.

6. **UART transmitter**
   - Sends sample packets through the Basys 3 USB-UART connection.
   - Uses a documented baud rate and packet format.
   - Holds output data stable while the downstream interface is busy.

7. **Self-checking verification environment**
   - Behavioral MPU6050/I2C slave model.
   - Test driver, monitor, reference model, and scoreboard.
   - Directed tests followed by randomized timing and fault injection.
   - SystemVerilog Assertions and functional coverage.

## Stretch features

Only begin these after the complete MVP passes regression and runs on hardware:

1. Fixed-point calibration or moving-average filter.
2. BRAM circular history buffer.
3. Performance and error counters through a simple register bank.
4. AXI-Stream output.
5. AXI-Lite control/status adapter.
6. A second clock domain with an asynchronous FIFO and CDC constraints.
7. SECDED ECC for the BRAM buffer.

If the schedule slips, remove stretch features before reducing verification quality.

## How to build it

Use the same engineering loop for every block:

1. Write the behavior and interface contract in plain language.
2. Draw the state machine or datapath.
3. List normal cases, boundary cases, and failure cases.
4. Write the self-checking testbench or reference behavior.
5. Write the RTL yourself.
6. Simulate directed cases.
7. Inspect waveforms and fix the root cause of each mismatch.
8. Add randomized or boundary testing.
9. Add assertions for the properties that must always hold.
10. Run the full regression before integrating the next block.

AI may explain concepts, review specifications, ask design questions, review code you wrote, and help interpret errors. It should not author the project RTL for you. You must be able to explain every state, register, timing relationship, and verification result.

## Build phases and completion gates

### Phase 0 — Tools and fundamentals

Estimated time: 2–4 focused days.

- Install AMD Vivado with Artix-7 device support.
- Confirm the Basys 3 part `XC7A35T-1CPG236C` is selectable.
- Complete HDLBits exercises covering:
  - Combinational logic.
  - Always blocks and nonblocking assignments.
  - Registers, counters, and shift registers.
  - Finite-state machines.
  - Modules and parameterization.
- Review the difference between software execution and concurrent hardware.
- Learn how to run simulation and inspect a waveform before starting the sensor interface.

**Done when:** you can write and simulate a small counter and FSM without copying a solution.

### Phase 1 — Freeze the specification

Estimated time: 3–5 hours.

- Draw the MVP block diagram.
- Define clock frequency and reset behavior.
- Define the interface of every module.
- Define the I2C target frequency.
- Define the sensor initialization register sequence.
- Define the internal sample packet bit layout.
- Define FIFO depth and overflow behavior.
- Define UART baud rate and output packet format.
- Write the initial verification test list.

**Done when:** the design can be discussed without relying on unwritten assumptions.

### Phase 2 — I2C engine

Estimated time: 1–2 weeks.

- Begin with START, STOP, and one transmitted byte.
- Add ACK/NACK detection.
- Add received bytes and master ACK/NACK generation.
- Add repeated START.
- Add timeout and error reporting.
- Verify each operation against a behavioral slave.

Minimum assertions:

- SDA changes only during the allowed SCL phase except for START and STOP.
- Every accepted command eventually completes or reports an error.
- Reset returns the controller and pins to their documented idle state.

**Done when:** directed and error-injection tests pass without an MPU6050-specific controller.

### Phase 3 — MPU6050 model and acquisition controller

Estimated time: about 1 week.

- Create a behavioral I2C slave model with a small register map.
- Model the required MPU6050 identity, power-management, and sample registers.
- Implement the initialization sequence.
- Implement the 14-byte burst read.
- Verify byte ordering and signed sample reconstruction.
- Inject NACKs, response delays, and reset during transactions.

**Done when:** the controller initializes the model and produces correct samples or explicit error results.

### Phase 4 — Packetizer and FIFO

Estimated time: about 1 week.

- Freeze the fixed-width sample packet.
- Add a monotonic timestamp or sample counter.
- Implement the parameterized synchronous FIFO.
- Test empty, one-entry, almost-full, full, overflow, underflow, and wraparound.
- Randomize producer and consumer timing.

Minimum assertions:

- A write is never accepted when full.
- A read is never accepted when empty.
- Accepted samples are not lost, duplicated, or reordered.
- Valid output remains stable while backpressured.

**Done when:** a scoreboard proves correct ordering under randomized pressure.

### Phase 5 — UART and integrated simulation

Estimated time: 3–5 focused days.

- Implement the UART transmitter separately.
- Verify start bit, data order, stop bit, and baud timing.
- Connect the packetizer/FIFO output to UART.
- Decode the serial stream in the testbench.
- Compare decoded packets with the reference model.

**Done when:** an end-to-end simulated sensor sample is reconstructed correctly at the UART output.

### Phase 6 — Verification hardening

Estimated time: about 1 week.

- Add randomized sensor values and response delays.
- Inject ACK/NACK failures at every address and data phase.
- Reset during idle and active transactions.
- Exercise all FIFO occupancy boundaries.
- Add functional coverage for transaction types, error positions, reset phases, occupancy boundaries, and controller states.
- Automate a repeatable regression command.

**Done when:** regression passes, coverage holes are understood, and at least three real bugs and their fixes are documented.

### Phase 7 — Synthesis and Basys 3 bring-up

Estimated time: about 1 week.

- Add the official Basys 3 constraints for only the pins actually used.
- Synthesize and implement the design.
- Review inferred latches, warnings, utilization, and timing.
- Require non-negative setup timing slack.
- Bring up UART before connecting the sensor.
- Verify 3.3 V compatibility and sensor pull-up voltage.
- Connect the MPU6050 through a Pmod header.
- Use Vivado ILA if simulation and hardware behavior disagree.

**Done when:** the real sensor produces correct, timestamped laptop-visible samples and the measured implementation results are recorded.

### Phase 8 — Portfolio packaging

Estimated time: 2–3 focused days.

- Write a concise README.
- Add the architecture diagram and module descriptions.
- Publish the verification plan and results.
- Include normal and error waveform screenshots.
- Record the regression result, functional coverage, clock target, worst slack, LUT/FF/BRAM use, FIFO depth, sensor rate, and UART rate.
- Record a short demonstration video or GIF.
- Write the resume bullet using measured values only.

**Done when:** another engineer can reproduce the simulation and understand the design without asking for missing information.

## First working session

Do these tasks first:

1. Install or open Vivado and confirm Artix-7/Basys 3 support.
2. Create a blank practice project—not the final sensor design.
3. Write a small counter and a two-state FSM yourself.
4. Simulate both and inspect their waveforms.
5. Complete at least ten relevant HDLBits exercises.
6. On paper or in a new design note, draw the MVP block diagram.
7. Decide and document:
   - System clock frequency.
   - Reset polarity and whether it is synchronous.
   - I2C clock target.
   - FIFO packet width and initial depth.
   - UART baud rate.
8. Stop before writing the I2C engine and review the specification for missing assumptions.

The first session is successful if the toolchain works, a waveform is visible, and the initial architecture decisions are written down. It does not need to produce sensor RTL.

## Suggested repository organization

Create this structure when starting the Git repository:

```text
docs/          specifications, architecture, verification plan, results
rtl/           synthesizable SystemVerilog written by you
tb/            models, drivers, monitors, scoreboard, assertions, tests
constraints/   Basys 3 XDC constraints
scripts/       repeatable simulation and regression commands
reports/       selected synthesis, timing, utilization, and coverage summaries
```

Do not commit Vivado's large generated project directories. Commit source RTL, testbench code, constraints, scripts, documentation, and selected reports.

## Materials

- Digilent Basys 3, part 410-183 — ordered 2026-07-18; delivery was expected around 2026-07-25 but is not marked received yet.
- Existing 3.3 V-safe MPU6050 breakout.
- Male-to-female jumper wires.
- USB-A to Micro-B data cable.

Do not buy another FPGA board, a custom PCB, or an expensive logic analyzer for the MVP. Use Vivado simulation and ILA first.

## Definition of done

The project is application-ready only when:

- A real MPU6050 streams correct timestamped samples from the Basys 3 to a laptop.
- Automated self-checking regression covers normal, boundary, and injected-error cases.
- Assertions and functional coverage are present and explained.
- The design meets its timing constraint with non-negative slack.
- Measured utilization and performance results are documented.
- The repository contains reproducible commands, architecture, verification evidence, waveforms, and a hardware demonstration.
- You can explain at least three bugs found by verification and how you fixed them.

Until physical bring-up occurs, use an honest status such as:

> RTL implementation and software simulation in progress; FPGA hardware verification pending.

## Resume bullet template

Do not use this until the claims are true and every bracket contains a measured value:

> Designed an FPGA IMU acquisition engine in SystemVerilog with a synthesizable I2C controller, timestamped [DEPTH]-entry FIFO, fixed-point filtering, and UART/AXI-Stream output; verified using a self-checking sensor model, randomized fault injection, SystemVerilog Assertions, and [COVERAGE]% functional coverage; synthesized on Artix-7 at [FMAX] MHz using [LUTS] LUTs, [FFS] flip-flops, and [BRAM] BRAMs.
