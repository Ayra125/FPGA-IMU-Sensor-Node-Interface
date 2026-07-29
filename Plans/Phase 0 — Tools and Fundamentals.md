---
title: Phase 0 — Tools and Fundamentals
status: in-progress
started: 2026-07-25
---

# Phase 0 — Tools and Fundamentals

## Objective

Establish a working SystemVerilog simulation workflow and a supported Vivado path before beginning the sensor RTL.

This phase is complete when:

- A counter and a two-state FSM have been written without copying a solution.
- Both designs have been simulated and their waveforms inspected.
- At least ten relevant HDLBits exercises are complete.
- Vivado can target the Basys 3 part `XC7A35T-1CPG236C` on a supported x86-64 host.

## Environment audit — 2026-07-25

Observed on the development machine:

- Host: Apple-silicon Mac (`arm64`), macOS 26.6.
- Native Vivado: not installed.
- Existing Parallels VM: Windows 11, stopped, ARM64 guest.
- Local HDL tools: Homebrew, Icarus Verilog 13.0, and Surfer 0.7.0 are installed. Verilator and Yosys are not currently installed.

AMD's Vivado 2026.1 documentation lists supported operating systems on **x86-64 processor architectures**. Therefore the current Windows ARM VM is not the supported Vivado path.

## Working strategy

Use two separate toolchain tracks:

1. **Local learning and simulation**
   - Use the Mac for HDLBits and small SystemVerilog exercises.
   - Install a lightweight simulator and waveform viewer if a browser-only workflow is insufficient.
   - Keep these exercises separate from the final sensor design.

2. **Vivado and hardware**
   - Use a supported x86-64 Windows or Linux machine for synthesis, implementation, bitstream generation, and Basys 3 programming.
   - Candidate hosts: a university lab machine, an existing x86-64 PC, or a remote x86-64 workstation with a later plan for physical USB/JTAG access.

Do not attempt the full Vivado installation in the ARM64 Parallels VM unless AMD adds explicit ARM64 support.

### Decision — 2026-07-25

Selected the recommended split workflow:

- The Mac is the primary environment for editing, HDLBits, simulation, waveforms, tests, documentation, and Git.
- A supported x86-64 host will be used only for Vivado synthesis, implementation, timing reports, bitstream generation, and hardware checkpoints.
- The initial native Mac tools will be Icarus Verilog for event-driven SystemVerilog exercises and Surfer for waveform inspection. Verilator can be added later for linting and faster regressions.

## First working session

- [x] Audit the host, VM architecture, and installed HDL tools.
- [x] Install and verify Icarus Verilog 13.0 and Surfer 0.7.0 on the Mac.
- [ ] Choose the x86-64 Vivado host.
- [ ] Confirm the chosen host has enough free disk space for Vivado plus Artix-7 device support.
- [ ] Install or open Vivado on that host.
- [ ] Confirm `XC7A35T-1CPG236C` is selectable.
- [x] Choose the local simulation route: Homebrew tools alongside HDLBits.
- [ ] Write a small counter.
- [ ] Write a two-state FSM.
- [ ] Write self-checking testbenches for both.
- [ ] Run both simulations and inspect their waveforms.
- [ ] Complete ten relevant HDLBits exercises.
- [ ] Begin the Phase 1 specification only after the Phase 0 completion gate passes.

## Decisions needed

- Which x86-64 machine will run Vivado?
- Where should practice exercises live so they remain separate from final portfolio RTL?

## Guardrail

The learner writes the RTL. AI support may explain concepts, review specifications and code, propose tests, and help diagnose simulator or synthesis errors.
