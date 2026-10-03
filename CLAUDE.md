# FPGA IMU Sensor Node Interface — project harness wiring

Part of the personal adaptive harness (`~/.claude/harness/README.md`). This project
builds a synthesizable SystemVerilog data-acquisition pipeline for an MPU6050 on a
Digilent Basys 3. Good work here is phase-gated, self-checking in simulation, and
careful not to claim synthesis or hardware results before they have been measured.

## Dominant profiles here

- `rtl` — design and verify the I2C controller, acquisition FSM, timestamping,
  packetizer, FIFO, UART transmitter, and their testbenches.
- `circuit` — reason about the MPU6050/Basys 3 electrical interface and physical
  bring-up constraints.
- `teaching` — build SystemVerilog and FPGA understanding through the Phase 0
  exercises and later design reviews.

## Project rules

- Read `README.md` first for the current phase, architecture, target hardware, and
  verification status.
- Respect the current phase gates in README.md. Phase 0/tool flow and Phase 2 I2C simulation are complete; Phase 3 is active. Do not restart completed gates from historical notes.
- Every RTL change needs a self-checking testbench and a real simulation run; a
  printed `PASS` must agree with a successful process exit status.
- Keep the design synthesizable for the Basys 3 Artix-7 target and document protocol,
  timing, reset, and error behavior before implementation.
- Do not claim synthesis, timing, resource, or physical-hardware results until the
  corresponding Vivado or board evidence exists.

## Outcome logging

Log substantive tasks per the profile skills, adding `"project":"fpga-imu"` to the
JSON line in `~/.claude/harness/outcomes.jsonl`.
