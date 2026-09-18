# RISC-V RV32I SoC with AXI4-Lite Interconnect & Peripherals

[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-blue.svg)](https://riscv.org/)
[![Bus Protocol](https://img.shields.io/badge/Bus-AXI4--Lite-orange.svg)](https://developer.arm.com/documentation/ihi0022/e/)
[![Verification](https://img.shields.io/badge/Verification-Layered%20SystemVerilog-green.svg)](verification/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Cadence%20Genus%20(100%20MHz)-blueviolet.svg)](Physical%20Design/)
[![Formal Verification](https://img.shields.io/badge/LEC-Cadence%20Conformal-brightgreen.svg)](Physical%20Design/)

A complete, silicon-ready System-on-Chip (SoC) design based on the **32-bit RISC-V (RV32I)** architecture. The system integrates an RV32I processor core with a memory-mapped **AXI4-Lite interconnect subsystem**, a hardware **Pulse-Width Modulation (PWM) peripheral**, an industry-grade **layered SystemVerilog verification environment**, and **ASIC physical design synthesis & formal equivalence verification results** (Cadence Genus + Conformal LEC).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Key Features](#key-features)
3. [Memory Map & Register Definition](#memory-map--register-definition)
4. [Hardware Implementation Details](#hardware-implementation-details)
   - [Multicycle FSM Controller](#multicycle-fsm-controller)
   - [AXI4-Lite Master Adapter](#axi4-lite-master-adapter)
   - [AXI4-Lite Interconnect / Crossbar](#axi4-lite-interconnect--crossbar)
   - [PWM Peripheral](#pwm-peripheral)
5. [Directory Structure](#directory-structure)
6. [Design Verification (DV)](#design-verification-dv)
   - [Layered Testbench Architecture](#layered-testbench-architecture)
   - [Test Suites & Coverage](#test-suites--coverage)
   - [Single-Cycle vs. Multicycle AXI Stalling Finding](#single-cycle-vs-multicycle-axi-stalling-finding)
7. [Physical Design & ASIC Synthesis](#physical-design--asic-synthesis)
   - [Synthesis Constraints](#synthesis-constraints)
   - [Quality of Results (QoR) Summary](#quality-of-results-qor-summary)
   - [Logic Equivalence Checking (LEC)](#logic-equivalence-checking-lec)
8. [Getting Started & Simulation](#getting-started--simulation)
   - [Prerequisites](#prerequisites)
   - [Running Multicycle SoC Simulation](#running-multicycle-soc-simulation)
   - [Running the Layered Verification Suite](#running-the-layered-verification-suite)

---

## Architecture Overview

```
                          +-------------------------------------------------------------+
                          |                 RISC-V RV32I MULTICYCLE CORE                |
                          |                                                             |
+------------------+      |  +----------+       +---------------+       +------------+  |
| Instruction SRAM | <----+--|  PC Reg  | ----> | IR / Saved PC | ----> |  FSM Ctrl  |  |
|    (4 KB Local)  |         +----------+       +---------------+       +-----+------+  |
+------------------+                                                          |         |
                                                                              |         |
                          |  +----------+       +---------------+             |         |
                          |  | Reg File | ----> |  A / B Regs   |             |         |
                          |  +----------+       +-------+-------+             |         |
                          |                             |                     |         |
                          |  +----------+               v                     |         |
                          |  | Imm Gen  | ------> [ ALU Muxes ]               |         |
                          |  +----------+               |                     |         |
                          |                             v                     |         |
                          |  +----------+       +---------------+             |         |
                          |  | Writeback| <---- |   ALU & Out   |             |         |
                          |  |   Mux    |       +-------+-------+             |         |
                          +-----------------------------|---------------------|---------+
                                                        | Address / Data      | mem_ready /
                                                        v                     | read_data
                          +---------------------------------------------------v---------+
                          |                      MEMORY ARBITRATION                     |
                          |   - Local Access (< 0x4000_0000): Local Data SRAM           |
                          |   - Peripheral Access (>= 0x4000_0000): AXI4-Lite Adapter   |
                          +-----------------+-------------------------------------------+
                                            |
                   +------------------------+------------------------+
                   | (Address < 0x4000_0000)                         | (Address >= 0x4000_0000)
                   v                                                 v
        +----------------------+                         +----------------------+
        |      Data SRAM       |                         |  AXI4-Lite Adapter   |
        |    (4 KB Local)      |                         |       (Master)       |
        +----------------------+                         +-----------+----------+
                                                                     |
                                                                     | AXI4-Lite Channels
                                                                     | (AW, W, B, AR, R)
                                                                     v
                                                         +----------------------+
                                                         | AXI4-Lite Interconnect
                                                         |  (Address Decoder)   |
                                                         +---+----+----+----+---+
                                                             |    |    |    |
                  +------------------------------------------+    |    |    +-----------------------------+
                  | (0x4000_xxxx)                                 |    |                                  | (0x4003_xxxx)
                  v                                               v    v                                  v
        +-------------------+                            +----------------+ +----------------+ +-------------------+
        |  PWM Peripheral   |                            | Timer (0x4001) | | GPIO (0x4002)  | |  UART Peripheral  |
        | (Period/Duty/Ctrl)|                            |                | |                | |                   |
        +---------+---------+                            +----------------+ +----------------+ +-------------------+
                  |
                  v pwm_out
```

---

## Key Features

- **RV32I Instruction Set Support**: Complete implementation of RV32I base user-level integer instructions:
  - **R-Type**: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
  - **I-Type ALU**: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
  - **Memory Operations**: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw` with byte-alignment masking
  - **Control Flow**: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
  - **Upper Immediates**: `lui`, `auipc`
- **Robust Multicycle Microarchitecture**:
  - Predictable multi-state execution: **FETCH &rarr; DECODE &rarr; EXECUTE &rarr; MEMORY &rarr; WRITEBACK**.
  - Internal pipeline registers: `IR` (Instruction Register), `pc_saved`, `A` & `B` operand registers, `ALUOut`, and `MDR` (Memory Data Register).
  - Explicit wait-state stalling on memory/bus transactions using `mem_ready`.
- **AXI4-Lite Bus Infrastructure**:
  - Single master to multi-slave interconnect implementing standard 5-channel AXI4-Lite handshake: Write Address (`AW`), Write Data (`W`), Write Response (`B`), Read Address (`AR`), Read Data (`R`).
  - Strict boundary isolation between internal scratchpad memory (`< 0x4000_0000`) and peripheral I/O space (`>= 0x4000_0000`).
- **Programmable PWM Subsystem**:
  - Independent 32-bit hardware period and duty-cycle counters.
  - Glitch-free active-high output generation with programmable enable.
- **ASIC Proven Flow**:
  - Synthesized with **Cadence Genus** at 100 MHz clock frequency with zero setup/hold timing violations.
  - Formally verified through **Cadence Conformal LEC** proving 100% equivalence between RTL and gate-level netlist.

---

## Memory Map & Register Definition

The system address space is partitioned into local memory (low address range) and memory-mapped peripheral I/O (high address range):

### System Memory Map

| Address Range | Size | Region Description | Target Subsystem |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_0FFF` | 4 KB | Instruction Memory (SRAM) | Local Instruction Memory (`instr_mem`) |
| `0x0000_1000 - 0x3FFF_FFFF` | ~1 GB | Data Scratchpad & Local RAM | Local Data Memory (`data_mem`) |
| `0x4000_0000 - 0x4000_FFFF` | 64 KB | PWM Peripheral Registers | AXI4-Lite Interconnect &rarr; `pwm_peripheral` |
| `0x4001_0000 - 0x4001_FFFF` | 64 KB | Timer Peripheral Space | AXI4-Lite Interconnect &rarr; `timer_peripheral` |
| `0x4002_0000 - 0x4002_FFFF` | 64 KB | General Purpose I/O (GPIO) | AXI4-Lite Interconnect &rarr; `gpio_peripheral` |
| `0x4003_0000 - 0x4003_FFFF` | 64 KB | UART Controller Space | AXI4-Lite Interconnect &rarr; `uart_peripheral` |

### PWM Peripheral Registers (`Base: 0x4000_0000`)

| Offset | Name | Type | Reset | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x00` | **`CONTROL_REG`** | R/W | `0x0000_0000` | Bit `[0]`: PWM Enable (`1` = Run, `0` = Stop/Reset counter). Bits `[31:1]`: Reserved. |
| `0x04` | **`PERIOD_REG`**  | R/W | `0x0000_0000` | 32-bit total PWM cycle duration in clock periods ($T_{PWM} = \text{PERIOD} \times T_{clk}$). |
| `0x08` | **`DUTY_REG`**    | R/W | `0x0000_0000` | 32-bit threshold for high output duration ($T_{HIGH} = \text{DUTY} \times T_{clk}$). |

#### Example Assembly Configuration Sequence:
```assembly
# Configure PWM: Period = 100 cycles, Duty = 25 cycles (25% Duty Cycle), Enable = 1
lui  x9, 0x40000        # x9  = 0x4000_0000 (Base Address)
addi x10, x0, 100       # x10 = 100
sw   x10, 4(x9)         # Write PERIOD_REG (0x4000_0004) = 100
addi x11, x0, 25        # x11 = 25
sw   x11, 8(x9)         # Write DUTY_REG   (0x4000_0008) = 25
addi x12, x0, 1         # x12 = 1 (Enable bit)
sw   x12, 0(x9)         # Write CONTROL_REG(0x4000_0000) = 1 (Start PWM)
```

---

## Hardware Implementation Details

### Multicycle FSM Controller
The core replaces the single-cycle combinational data loop with a synchronized 5-state Mealy/Moore controller (`controller_fsm.sv`):

```
          +-----------+
          |  S_FETCH  | (ir_write=1, pc_write=1, pc_src=PC+4)
          +-----+-----+
                |
                v
          +-----------+
          |  S_DECODE | (A<=rs1, B<=rs2, decode opcode/funct)
          +-----+-----+
                |
         +------+--------------------+--------------------+
         |                           |                    |
         v (R/I-Type)                v (Load/Store)       v (Branch / Jump)
   +-----------+               +-----------+        +-----------+
   | S_EXECUTE |               | S_EXECUTE |        | S_EXECUTE | (Branch / JAL / JALR:
   +-----+-----+               | (Address) |        |           |  Evaluate & update PC)
         |                     +-----+-----+        +-----+-----+
         |                           |                    |
         |                           v                    +---> [ Finish & Return to FETCH ]
         |                     +-----------+
         |                     | S_MEMORY  | <----+ (Wait for mem_ready)
         |                     +-----+-----+ -----+
         |                           |
         |             +-------------+-------------+
         |             | (Load)                    | (Store)
         |             v                           v
         |       +-------------+             +---> [ Finish & Return to FETCH ]
         |       | S_WRITEBACK |
         |       +-------+-----+
         |               |
         v               v
   +---------------------------+
   |        S_WRITEBACK        | (reg_write=1, reg_write_src=ALUOut or MDR)
   +-------------+-------------+
                 |
                 +---> [ Return to FETCH ]
```

- **Wait-State Awareness**: When accessing slow bus peripherals or AXI slaves, the FSM stalls in `S_MEMORY` until `mem_ready == 1'b1`.

### AXI4-Lite Master Adapter
Located in `multicycle/axi_adapter.sv`, this module interfaces the CPU memory stage to AXI4-Lite slaves:
- **Write FSM**: `IDLE` &rarr; `WRITE_ADDR` (`awvalid`) &rarr; `WRITE_DATA` (`wvalid`, `wstrb=4'hF`) &rarr; `WRITE_RESP` (`bready`) &rarr; `IDLE`.
- **Read FSM**: `IDLE` &rarr; `READ_ADDR` (`arvalid`) &rarr; `READ_DATA` (`rready`) &rarr; `IDLE`.
- **Stall Logic**: Deasserts `mem_ready` during outstanding transactions, keeping the processor FSM paused until the final handshake (`bvalid` or `rvalid`).

### AXI4-Lite Interconnect / Crossbar
Located in `multicycle/axi_interconnect.sv`:
- Decodes address bits `addr[31:16]` to route channel signals to the appropriate slave device.
- Multiplexes read data and response handshakes back to the master adapter.

### PWM Peripheral
Located in `multicycle/pwm_peripheral.sv`:
- Implements AXI4-Lite slave write and read state machines.
- Features a 32-bit free-running counter that resets when `counter >= period_reg`.
- Output signal: `pwm_out = (control_reg[0]) && (counter < duty_reg)`.

---

## Directory Structure

```
RiscV-AxiController/
├── multicycle/                        # Multicycle RV32I Processor & SoC RTL
│   ├── riscv_soc_mc.sv                # Top-level Multicycle SoC module
│   ├── controller_fsm.sv              # 5-stage FSM Controller
│   ├── alu.sv                         # Arithmetic Logic Unit
│   ├── alu_control.sv                 # ALU Operation Decoder
│   ├── imm_gen.sv                     # Immediate Generator
│   ├── reg_file.sv                    # 32 x 32-bit Register File
│   ├── pc_reg.sv                      # Program Counter with write enable
│   ├── instr_mem.sv                   # Instruction Memory (4 KB)
│   ├── data_mem.sv                    # Data Memory with byte/half/word support
│   ├── axi_adapter.sv                 # AXI4-Lite Master Adapter
│   ├── axi_interconnect.sv            # AXI4-Lite Interconnect / Decoder
│   ├── pwm_peripheral.sv              # Memory-mapped PWM Peripheral
│   ├── hex_file.hex                   # Default test program for PWM
│   ├── tb_riscv_core_mc.sv            # Standalone Core Testbench
│   ├── tb_riscv_soc_mc.sv             # Multicycle SoC + PWM Testbench
│   ├── compile.bat                    # ModelSim compilation script
│   ├── run_sim.bat                    # Simulation run script with VCD export
│   └── riscv_soc_mc.qpf / .qsf        # Intel Quartus Prime project files
│
├── Physical Design/                   # ASIC Implementation & Synthesis
│   ├── constraints.sdc                # SDC Timing & I/O Constraints (100 MHz)
│   ├── genus.cmd / genus.log          # Cadence Genus execution logs
│   ├── capstone.do / capstone_lec.log # Cadence Conformal LEC formal verification
│   ├── report_qor.rpt                 # Quality of Results (QoR) summary
│   ├── report_timing.rpt              # Static Timing Analysis (STA) report
│   ├── report_area.rpt                # Cell count and area breakdown
│   ├── report_power.rpt               # Dynamic & leakage power report
│   └── unmapped.rpt                   # Netlist mapping inspection report
│
├── verification/                      # Layered Verification Suite (DV)
│   ├── README.md                      # Detailed verification testbench guide
│   ├── tb_soc_layered.sv              # Top Layered Testbench for SoC
│   ├── tb_single_cycle_core_layered.sv# Layered Testbench for standalone Core
│   ├── tb_multicycle_soc.sv           # Multicycle SoC test wrapper
│   ├── tb_multicycle_core.sv          # Multicycle Core test wrapper
│   ├── run_questa_soc.bat             # QuestaSim runner for SoC testbench
│   ├── run_questa_single_cycle_core.bat
│   ├── run_questa_multicycle_soc.bat
│   ├── run_modelsim_soc.bat           # ModelSim runner for SoC testbench
│   ├── hex_file.hex                   # Default verification hex
│   ├── instructions_test.hex          # 22-instruction RV32I validation sequence
│   └── pwm_test.hex                   # Memory-mapped AXI PWM test hex
│
└── README.md                          # Repository Top-Level Documentation
```

---

## Design Verification (DV)

### Layered Testbench Architecture

The verification suite in `verification/tb_soc_layered.sv` is constructed using an object-oriented, layered verification methodology:

```
┌────────────────────────────────────────────────────────────────────────┐
│                              tb_top                                    │
│  - 100 MHz Clock Generator (10 ns period) & Power-on Reset             │
│  - Background AXI4-Lite Protocol & Handshake Monitor                   │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                      riscv_transaction                         │   │
│   │   Program hex stream, execution cycle budget, expected         │   │
│   │   register file state, expected data memory state, flags       │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                       riscv_generator                          │   │
│   │   Constructs directed & constrained transactions covering      │   │
│   │   ISA instructions, boundary cases, and bus transactions       │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                         Driver (drive)                         │   │
│   │   Backdoor memory loading, hardware reset pulsing, run-control │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                        Checker (check)                         │   │
│   │   Compares architectural registers (x1-x31) & SRAM against ref │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                           Scoreboard                           │   │
│   │   Aggregates transaction pass/fail verdicts and reports logs   │   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### Test Suites & Coverage

| Suite | Test Objective | Covered Scenarios |
| :---: | :--- | :--- |
| **TEST 1** | **Reset Verification** | Confirms registers `x1..x31` reset strictly to `0x0000_0000` with `x0` constant. |
| **TEST 2** | **R-Type ALU** | `add`, `sub`, `and`, `or`, `xor`, `slt`, signed/unsigned arithmetic edge cases. |
| **TEST 3** | **I-Type ALU** | Immediate sign extension for `addi`, `andi`, `ori`, `xori`, `slti`, `slli`, `srli`. |
| **TEST 4** | **Load & Store** | `sw`, `lw`, `sh`, `lh`, `sb`, `lb` with memory data integrity and alignment. |
| **TEST 5** | **Branch Resolution** | `beq`, `bne`, `blt`, `bge` taken vs. not-taken branch conditions and PC redirect. |
| **TEST 6** | **Unconditional Jumps**| `jal` and `jalr` target address calculation and link register storage (`PC + 4`). |
| **TEST 7** | **AXI Handshake & Write** | Verified AXI master handshake on address space `>= 0x4000_0000`. |
| **TEST 8** | **Address Decode Boundary** | Confirms memory accesses below `0x4000_0000` never leak into peripheral bus. |

### Single-Cycle vs. Multicycle AXI Stalling Finding
During verification, a critical architectural difference was identified:
1. **Single-Cycle Core Defect**: When an AXI peripheral write occurs, the AXI adapter asserts `busy = 1`. However, in a pure single-cycle core without intermediate stage registers, the PC register updates on the very next clock edge before the stall signal can propagate. This causes the PC to advance prematurely, changing `alu_result` and causing the bus request to drop mid-handshake.
2. **Multicycle Resolution**: In `riscv_soc_mc`, the multicycle FSM enters `S_MEMORY` and holds all controls (`ALUOut`, write data `B`, and address) stable until `mem_ready == 1'b1`. This guarantees full compliance with AXI4-Lite handshake timing rules.

---

## Physical Design & ASIC Synthesis

The design was synthesized using **Cadence Genus(TM) Synthesis Solution** targeting a standard cell ASIC library.

### Synthesis Constraints (`constraints.sdc`)
```tcl
create_clock -name clk -period 10.0 -waveform {0 5} [get_ports "clk"]
set_clock_transition -rise 0.1 [get_clocks "clk"]
set_clock_transition -fall 0.1 [get_clocks "clk"]
set_clock_uncertainty 0.01     [get_clocks "clk"]

set_input_delay  -max 1.0 [get_ports "reset"]          -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "pwm_out"]        -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "timer_overflow"] -clock [get_clocks "clk"]
```

### Quality of Results (QoR) Summary

| Parameter | Result | Notes |
| :--- | :--- | :--- |
| **Synthesis Tool** | Cadence Genus 26.10-p002_1 | Built on Rocky Linux 9.8 |
| **Target Clock Frequency** | **100.0 MHz** ($T_{clk} = 10.0\text{ ns}$) | Real-time embedded clock |
| **Worst Setup Slack** | **+1130.6 ps** (+1.13 ns) | **MET** (Zero timing violations) |
| **Total Negative Slack (TNS)** | **0.0 ps** | All paths satisfied |
| **Total Cell Area** | **$4675.14\ \mu\text{m}^2$** | Gate-level cell footprint |
| **Total Cell Count** | **1,852** instances | 287 Sequential, 1565 Combinational |
| **Total Power Consumption** | **$90.68\ \mu\text{W}$** | @ $0.9\text{V}$, $125^\circ\text{C}$ (PVT worst-case) |
| - *Internal Power* | $80.19\ \mu\text{W}$ (88.4%) | Standard cell internal switching |
| - *Switching Power* | $10.39\ \mu\text{W}$ (11.5%) | Interconnect net switching |
| - *Leakage Power* | $0.097\ \mu\text{W}$ (0.11%) | Static leakage |

### Area Breakdown by Module

```
+-------------------------------------------------------------------------------+
| Module Instance         | Submodule Type       | Cell Count | Cell Area (um^2)|
+-------------------------+----------------------+------------+-----------------+
| u_pwm_peripheral        | pwm_peripheral       |        446 |        1229.490 |
| u_timer_peripheral      | timer_peripheral     |        320 |         879.624 |
| u_reg_file              | reg_file             |        184 |         795.492 |
| u_pc_reg                | pc_reg               |         58 |         198.360 |
| u_instr_mem             | instr_mem            |         41 |          49.248 |
| u_axi_adapter           | axi_adapter          |         15 |          29.754 |
| u_axi_interconnect      | axi_interconnect     |         16 |          28.386 |
| u_control_unit          | decoder              |         11 |          14.022 |
| u_data_mem              | data_mem             |          3 |           6.840 |
| u_alu_control           | alu_control          |          5 |           5.814 |
| (Top glue & datapath)   | updated_top_module2  |        768 |        1447.910 |
+-------------------------+----------------------+------------+-----------------+
| TOTAL                   |                      |      1,852 |        4675.140 |
+-------------------------------------------------------------------------------+
```

### Logic Equivalence Checking (LEC)
Using **Cadence Conformal(R) LEC** (`Physical Design/capstone.do`):
- **Golden Model**: SystemVerilog RTL (`multicycle/*.sv`).
- **Revised Model**: Synthesized gate-level netlist (`updated_top_module2_netlist.v`).
- **Result**: **100% Compare Points Passed** with zero non-equivalences, zero aborts, and zero unmapped points.

---

## Getting Started & Simulation

### Prerequisites
- **EDA Simulator**: QuestaSim / ModelSim (e.g. Questa 2024.1 or Intel ModelSim Starter Edition).
- **Synthesis (Optional)**: Cadence Genus Synthesis Solution & Conformal LEC.
- **FPGA Tooling (Optional)**: Intel Quartus Prime Lite / Standard Edition.

---

### Running Multicycle SoC Simulation

To run the multicycle SoC testbench (which executes RISC-V instructions configuring the PWM peripheral over AXI4-Lite):

#### Via Windows Command Prompt:
```cmd
cd multicycle
compile.bat
run_sim.bat
```

#### Via QuestaSim / ModelSim GUI / CLI:
```bash
cd multicycle
vlib work
vlog -sv alu.sv alu_control.sv imm_gen.sv reg_file.sv pc_reg.sv instr_mem.sv data_mem.sv controller_fsm.sv axi_adapter.sv axi_interconnect.sv pwm_peripheral.sv riscv_soc_mc.sv tb_riscv_soc_mc.sv
vsim -c -do "vcd file wave.vcd; vcd add -r /tb_riscv_soc_mc/*; run -all; quit -f" work.tb_riscv_soc_mc
```

---

### Running the Layered Verification Suite

To run the automated verification suite covering the complete RV32I ISA and AXI interconnect:

#### Using QuestaSim:
```cmd
cd verification
run_questa_soc.bat
```

Or for the multicycle SoC:
```cmd
run_questa_multicycle_soc.bat
```

#### Using ModelSim:
```cmd
cd verification
run_modelsim_soc.bat
```

#### Inspecting Waveforms:
Open the generated `vsim.wlf` or `wave.vcd` in your waveform viewer:
```cmd
vsim -view vsim.wlf
```

---

## Authors & Contributors

- **Wali Shajeeh**
- **Mufeez Rasheed Khan**

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
