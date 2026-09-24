# RISC-V RV32I SoC with AXI4-Lite Interconnect & Peripherals

[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-blue.svg)](https://riscv.org/)
[![Bus Protocol](https://img.shields.io/badge/Bus-AXI4--Lite-orange.svg)](https://developer.arm.com/documentation/ihi0022/e/)
[![Verification](https://img.shields.io/badge/Verification-Layered%20SystemVerilog%20(58%20Passed)-green.svg)](verification/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Cadence%20Genus%20(100%20MHz)-blueviolet.svg)](Physical%20Design/)
[![Formal Verification](https://img.shields.io/badge/LEC-Cadence%20Conformal-brightgreen.svg)](Physical%20Design/)
[![FPGA](https://img.shields.io/badge/FPGA-Intel%20Cyclone%20V-0071C5.svg)](verification/)

A complete, silicon-ready System-on-Chip (SoC) design based on the **32-bit RISC-V (RV32I)** architecture. The system integrates an RV32I processor core with a memory-mapped **AXI4-Lite interconnect subsystem**, a full set of hardware peripherals (**PWM**, **Timer**, **GPIO**, **UART**), an industry-standard **modular layered SystemVerilog verification suite** (11 directed test cases with 58/58 passing assertions), **QuestaSim GUI/CLI project integration**, **Intel Quartus Prime synthesis**, and **ASIC physical design synthesis & formal equivalence verification results** (Cadence Genus + Conformal LEC).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Key Features](#key-features)
3. [Memory Map & Register Definition](#memory-map--register-definition)
   - [System Memory Map](#system-memory-map)
   - [PWM Peripheral Registers](#1-pwm-peripheral-base-0x4000_0000)
   - [Timer Peripheral Registers](#2-timer-peripheral-base-0x4001_0000)
   - [GPIO Peripheral Registers](#3-gpio-peripheral-base-0x4002_0000)
   - [UART Controller Registers](#4-uart-controller-base-0x4003_0000)
4. [Hardware Implementation Details](#hardware-implementation-details)
   - [Integrated SoC Top (`updated_top_module2`)](#integrated-soc-top-updated_top_module2)
   - [AXI4-Lite Master Adapter with Single-Cycle Stall Latching](#axi4-lite-master-adapter-with-single-cycle-stall-latching)
   - [AXI4-Lite Interconnect / Crossbar](#axi4-lite-interconnect--crossbar)
   - [Peripheral Modules (PWM, Timer, GPIO, UART)](#peripheral-modules)
   - [Multicycle RV32I Microarchitecture](#multicycle-rv32i-microarchitecture)
5. [Directory Structure](#directory-structure)
6. [Design Verification (DV)](#design-verification-dv)
   - [Modular Layered Testbench Architecture](#modular-layered-testbench-architecture)
   - [Test Suites & Coverage Matrix](#test-suites--coverage-matrix)
   - [Race-Free Driver-Monitor Handshake](#race-free-driver-monitor-handshake)
   - [Standalone Unit Testbenches](#standalone-unit-testbenches)
7. [Physical Design & ASIC Synthesis](#physical-design--asic-synthesis)
   - [Synthesis Constraints](#synthesis-constraints)
   - [Quality of Results (QoR) Summary](#quality-of-results-qor-summary)
   - [Logic Equivalence Checking (LEC)](#logic-equivalence-checking-lec)
8. [Getting Started & Simulation](#getting-started--simulation)
   - [Prerequisites](#prerequisites)
   - [Manual QuestaSim GUI Execution](#1-manual-questasim-gui-execution)
   - [One-Click Batch Simulation Scripts](#2-one-click-batch-simulation-scripts)
   - [Intel Quartus Prime Synthesis](#3-intel-quartus-prime-fpga-synthesis)
9. [Authors & Contributors](#authors--contributors)

---

## Architecture Overview

```
                          +-------------------------------------------------------------+
                          |                   RISC-V RV32I PROCESSOR CORE               |
                          |            (Single-Cycle with Synchronous Stall /           |
                          |             Multicycle FSM Execution Controller)            |
                          +-----------------------------+-------------------------------+
                                                        |
                                                        | Address / Write Data / Mem Control
                                                        v
                          +-------------------------------------------------------------+
                          |                      MEMORY ARBITRATION                     |
                          |   - Local Access (< 0x4000_0000): Local Data Memory (SRAM)  |
                          |   - Peripheral Access (>= 0x4000_0000): AXI4-Lite Adapter   |
                          +-----------------------------+-------------------------------+
                                                        |
                         +------------------------------+------------------------------+
                         | (Address < 0x4000_0000)                                     | (Address >= 0x4000_0000)
                         v                                                             v
              +----------------------+                                     +----------------------+
              |      Data SRAM       |                                     |  AXI4-Lite Adapter   |
              |    (Local Memory)    |                                     |    (Master Bridge)   |
              +----------------------+                                     +-----------+----------+
                                                                                       |
                                                                                       | AXI4-Lite Channels
                                                                                       | (AW, W, B, AR, R)
                                                                                       v
                                                                           +----------------------+
                                                                           | AXI4-Lite Crossbar   |
                                                                           | (Address Dec/Mux)    |
                                                                           +---+----+----+----+---+
                                                                               |    |    |    |
                   +-----------------------------------------------------------+    |    |    +-----------------------------+
                   | (0x4000_xxxx)                                                  |    |                                  | (0x4003_xxxx)
                   v                                                                |    |                                  v
         +-------------------+                                                      |    |                        +-------------------+
         |  PWM Peripheral   |                                                      |    |                        |  UART Peripheral  |
         | (Period/Duty/Ctrl)|                                                      |    |                        | (TX, RX, Regs)    |
         +---------+---------+                                                      |    |                        +----+---------+----+
                   |                                                                |    |                             |         |
                   v pwm_out                                                        v    v                             v uart_tx ^ uart_rx
                                                                           +----------------+ +----------------+
                                                                           | Timer (0x4001) | | GPIO (0x4002)  |
                                                                           | Compare/Count  | | (DIR, OUT, IN) |
                                                                           +-------+--------+ +---+--------+---+
                                                                                   |              |        |
                                                                                   v              v        ^
                                                                             timer_overflow    gpio_out  gpio_in
```

---

## Key Features

- **RV32I Base Integer Instruction Set**:
  - **R-Type**: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
  - **I-Type ALU**: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
  - **Memory Operations**: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw` with byte-alignment masking
  - **Control Flow**: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
  - **Upper Immediates**: `lui`, `auipc`
- **Comprehensive AXI4-Lite Peripheral Subsystem**:
  - **PWM Peripheral** (`0x4000_0000`): 32-bit hardware period and duty-cycle control, active-high toggle output.
  - **Timer Peripheral** (`0x4001_0000`): 32-bit free-running counter, programmable compare register, single-cycle `timer_overflow` interrupt/pulse.
  - **GPIO Peripheral** (`0x4002_0000`): 32-bit configurable direction (`DIR`), output register (`OUT`), and external input synchronizer (`IN`) with per-bit masking.
  - **UART Controller** (`0x4003_0000`): Standard 8N1 serial protocol with parameterizable baud rate, status polling (`TX_STATUS`, `RX_STATUS`), 2-FF synchronizer on `uart_rx`, and mid-bit sampling.
- **Robust Bus Interconnect & Master Bridge**:
  - Full 5-channel AXI4-Lite implementation (`AW`, `W`, `B`, `AR`, `R`).
  - Single-cycle core compatibility: Latched address, write data, and request registers prevent bus dropouts during processor stalls; zero-latency bypass for read data writeback.
- **Industry-Standard Verification Suite**:
  - Complete SystemVerilog modular layered testbench (`Generator`, `Driver`, `Monitor`, `Scoreboard`, `Environment`, `Transaction`, `Interface`).
  - 11 directed test scenarios with 58/58 passing assertions verifying processor datapath, branch/jump redirection, memory isolation, and full AXI write/read operations across all 4 peripherals.
  - Dedicated unit testbenches for GPIO (21 assertions passed) and UART (17 assertions passed).
- **Toolchain & ASIC Readiness**:
  - **QuestaSim Project (`riscv_soc.mpf`)**: Preconfigured project with 1-click GUI and waveform launchers.
  - **Intel Quartus Prime**: Synthesizable for Intel Cyclone V FPGA with 0 errors.
  - **Cadence Genus & Conformal LEC**: 100 MHz timing closure with zero violations and 100% formal equivalence.

---

## Memory Map & Register Definition

The 32-bit memory address space is strictly partitioned between local memories and memory-mapped AXI4-Lite peripherals:

### System Memory Map

| Address Range | Size | Region Description | Target Subsystem |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_0FFF` | 4 KB | Instruction Memory (ROM/SRAM) | Local Instruction Memory (`instr_mem`) |
| `0x0000_1000 - 0x3FFF_FFFF` | ~1 GB | Data Scratchpad & Local RAM | Local Data Memory (`data_mem`) |
| `0x4000_0000 - 0x4000_FFFF` | 64 KB | PWM Peripheral Space | AXI4-Lite Interconnect &rarr; `pwm_peripheral` |
| `0x4001_0000 - 0x4001_FFFF` | 64 KB | Timer Peripheral Space | AXI4-Lite Interconnect &rarr; `timer_peripheral` |
| `0x4002_0000 - 0x4002_FFFF` | 64 KB | GPIO Peripheral Space | AXI4-Lite Interconnect &rarr; `gpio_peripheral` |
| `0x4003_0000 - 0x4003_FFFF` | 64 KB | UART Controller Space | AXI4-Lite Interconnect &rarr; `uart_peripheral` |

---

### 1. PWM Peripheral (`Base: 0x4000_0000`)

| Offset | Name | Type | Reset | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x00` | **`CONTROL_REG`** | R/W | `0x0000_0000` | Bit `[0]`: Enable (`1` = Run, `0` = Stop counter). Bits `[31:1]`: Reserved. |
| `0x04` | **`PERIOD_REG`**  | R/W | `0x0000_0000` | 32-bit total PWM cycle length in clock ticks ($T_{PWM} = \text{PERIOD} \times T_{clk}$). |
| `0x08` | **`DUTY_REG`**    | R/W | `0x0000_0000` | 32-bit threshold for high output duration ($T_{HIGH} = \text{DUTY} \times T_{clk}$). |

---

### 2. Timer Peripheral (`Base: 0x4001_0000`)

| Offset | Name | Type | Reset | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x00` | **`CONTROL_REG`** | R/W | `0x0000_0000` | Bit `[0]`: Timer Start/Enable. Bit `[1]`: Counter Clear/Reset. Bits `[31:2]`: Reserved. |
| `0x04` | **`COUNTER_REG`** | R   | `0x0000_0000` | Current 32-bit counter value. Increments every clock cycle while enabled. |
| `0x08` | **`COMPARE_REG`** | R/W | `0x0000_0000` | 32-bit threshold. When `COUNTER == COMPARE`, pulses `timer_overflow` for 1 cycle. |

---

### 3. GPIO Peripheral (`Base: 0x4002_0000`)

| Offset | Name | Type | Reset | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x00` | **`DIR_REG`**     | R/W | `0x0000_0000` | Direction mask for 32 pins: `1` = Output, `0` = Input. |
| `0x04` | **`OUT_REG`**     | R/W | `0x0000_0000` | Output values. Only bits with `DIR[i] == 1` drive `gpio_out[i]`. |
| `0x08` | **`IN_REG`**      | R   | `0x0000_0000` | Synchronized external inputs sampled from `gpio_in[31:0]`. |

---

### 4. UART Controller (`Base: 0x4003_0000`)

| Offset | Name | Type | Reset | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x00` | **`TX_DATA_REG`**   | W   | `0x0000_0000` | Bits `[7:0]`: Data byte to transmit. Writing initiates 8N1 serial transmission. |
| `0x04` | **`TX_STATUS_REG`** | R   | `0x0000_0000` | Bit `[0]`: `1` = TX Busy (transmission in progress), `0` = Ready for next byte. |
| `0x08` | **`RX_DATA_REG`**   | R   | `0x0000_0000` | Bits `[7:0]`: Most recently received serial data byte. |
| `0x0C` | **`RX_STATUS_REG`** | R   | `0x0000_0000` | Bit `[0]`: `1` = RX Data Valid (new byte received), `0` = No new data. |

---

## Hardware Implementation Details

### Integrated SoC Top (`updated_top_module2`)
The unified system top entity (`verification/updated_top_module2.sv`) coordinates all on-chip modules:
- Instantiates the single-cycle RV32I processor core with PC control and memory adapters.
- Instantiates the `axi_adapter` master bridge.
- Instantiates the 1-Master to 4-Slave `axi_interconnect` crossbar.
- Instantiates `pwm_peripheral`, `timer_peripheral`, `gpio_peripheral`, and `uart_peripheral`.
- Exposes top-level I/O ports: `clk`, `reset`, `pwm_out`, `timer_overflow`, `gpio_out[31:0]`, `gpio_in[31:0]`, `uart_tx`, and `uart_rx`.

### AXI4-Lite Master Adapter with Single-Cycle Stall Latching
In a single-cycle core, stall propagation must be carefully balanced to prevent premature instruction retirement during multi-cycle AXI handshakes:
1. **Immediate Busy Assertion**: `busy = ((state != IDLE) || write_req || read_req) && !done`. The core stalls on the very cycle the memory stage accesses an address `>= 0x4000_0000`.
2. **Synchronous Request Latching**: Internal registers (`latched_addr`, `latched_data`, `active_write_req`, `active_read_req`) hold bus signals steady across all AXI wait states even if the core datapath fluctuates.
3. **Zero-Latency Read Data Bypass**: During read transactions, `rdata` is bypassed directly from `axi_rdata` when `axi_rvalid && axi_rready`, guaranteeing the processor register file latches the correct peripheral readback value on the retirement clock edge.

### AXI4-Lite Interconnect / Crossbar
Located in `verification/axi_interconnect.sv`:
- Decodes address bits `[19:16]` to route transactions to one of four slaves:
  - `0x0`: Slave 0 &rarr; PWM
  - `0x1`: Slave 1 &rarr; Timer
  - `0x2`: Slave 2 &rarr; GPIO
  - `0x3`: Slave 3 &rarr; UART
- Multiplexes read data (`rdata`), response handshakes (`bvalid`, `rvalid`), and ready signals back to the master adapter.

### Peripheral Modules
- **`pwm_peripheral.sv`**: Digital counter with programmable period and duty compare logic.
- **`timer_peripheral.sv`**: Continuous timer counter with comparator for scheduled interrupts.
- **`gpio_peripheral.sv`**: Tristate-aware I/O registers with input synchronization flip-flops.
- **`uart_peripheral.sv`**: Full-duplex asynchronous serial transceiver with configurable clock prescaler (`CLKS_PER_BIT`).

### Multicycle RV32I Microarchitecture
Located in `multicycle/`:
- Multi-state execution FSM: **FETCH &rarr; DECODE &rarr; EXECUTE &rarr; MEMORY &rarr; WRITEBACK**.
- Features explicit `mem_ready` handshaking that holds instruction execution during slow memory or peripheral access.

---

## Directory Structure

```
RiscV-AxiController/
├── .gitignore                         # Build and simulation artifact exclusion rules
├── README.md                          # Repository Top-Level Documentation
│
├── verification/                      # Unified Quartus & QuestaSim Verification Environment
│   ├── README.md                      # Detailed verification guide and execution notes
│   ├── single_cycle_core.qpf          # Intel Quartus Prime Project File
│   ├── single_cycle_core.qsf          # Quartus Project Settings (Cyclone V FPGA)
│   ├── riscv_soc.mpf                  # QuestaSim Project File (GUI & CLI)
│   ├── create_project.tcl             # QuestaSim Project Recreation / Tcl Build Script
│   │
│   ├── [RTL Modules]
│   │   ├── updated_top_module2.sv     # SoC Top-Level Entity (Core + AXI + 4 Peripherals)
│   │   ├── riscv_core.sv              # RV32I Core Datapath & Wiring
│   │   ├── alu.sv / alu_control.sv    # 32-bit ALU & Control Decoder
│   │   ├── imm_gen.sv                 # RV32I Immediate Generator
│   │   ├── reg_file.sv                # 32 x 32-bit Register File
│   │   ├── pc_reg.sv / pc_control.sv  # Program Counter & Flow Control
│   │   ├── decoder.sv                 # Main RV32I Instruction Decoder
│   │   ├── instr_mem.sv / data_mem.sv # Local Instruction & Data SRAM Subsystems
│   │   ├── axi_adapter.sv             # AXI4-Lite Master Bridge (with stall latching)
│   │   ├── axi_interconnect.sv        # 1-Master to 4-Slave Crossbar Interconnect
│   │   ├── pwm_peripheral.sv          # AXI4-Lite PWM Subsystem
│   │   ├── timer_peripheral.sv        # AXI4-Lite Timer Subsystem
│   │   ├── gpio_peripheral.sv         # AXI4-Lite GPIO Subsystem
│   │   ├── uart_tx.sv / uart_rx.sv    # UART Serial Transmitter & Receiver
│   │   ├── uart_regs.sv               # UART AXI4-Lite Register Block
│   │   └── uart_peripheral.sv         # Top UART Peripheral Wrapper
│   │
│   ├── [Layered Verification Testbench]
│   │   ├── soc_intf.sv                # SystemVerilog SoC Interface
│   │   ├── transaction.sv             # Verification Transaction Object
│   │   ├── generator.sv               # 11 Directed Test Cases Generator
│   │   ├── driver.sv                  # Reset & Stimulus Driver with Memory Loader
│   │   ├── monitor.sv                 # Register, Memory, & Signal Observer
│   │   ├── scoreboard.sv              # Reference Model & Assertion Checker
│   │   ├── environment.sv             # Component Wiring & Mailbox Orchestrator
│   │   └── top_tb.sv                  # Testbench Top Module & Clock Generator
│   │
│   ├── [Unit Testbenches]
│   │   ├── tb_gpio.sv                 # Standalone GPIO Unit Testbench (21 Assertions)
│   │   └── tb_uart.sv                 # Standalone UART Unit Testbench (17 Assertions)
│   │
│   └── [1-Click Execution Scripts]
│       ├── open_questa_gui.bat        # Opens QuestaSim GUI with riscv_soc.mpf loaded
│       ├── run_questa_gui_wave.bat    # Launches QuestaSim GUI with waveforms loaded
│       ├── run_questa_soc_modular.bat # One-click CLI simulation (58/58 Passed)
│       ├── run_questa_gpio.bat        # Runs standalone GPIO verification (21/21 Passed)
│       └── run_questa_uart.bat        # Runs standalone UART verification (17/17 Passed)
│
├── multicycle/                        # Multicycle RV32I Processor Subsystem
│   ├── riscv_soc_mc.sv                # Multicycle SoC Top Module
│   ├── controller_fsm.sv              # 5-stage FSM Controller
│   ├── compile.bat / run_sim.bat      # ModelSim simulation scripts
│   └── riscv_soc_mc.qpf / .qsf        # Quartus Prime project files
│
└── Physical Design/                   # ASIC Implementation & Synthesis (Cadence Genus + LEC)
    ├── constraints.sdc                # SDC Timing Constraints (100 MHz)
    ├── genus.cmd / genus.log          # Cadence Genus execution logs
    ├── capstone.do / capstone_lec.log # Cadence Conformal LEC formal verification
    ├── report_qor.rpt                 # Quality of Results (QoR) summary
    ├── report_timing.rpt              # Static Timing Analysis report
    └── report_area.rpt / power.rpt    # Area & power breakdown reports
```

---

## Design Verification (DV)

### Modular Layered Testbench Architecture

The verification suite in `verification/` follows the standard object-oriented SystemVerilog layered architecture:

```
┌────────────────────────────────────────────────────────────────────────┐
│                              top_tb                                    │
│  - 100 MHz Clock Generator (10 ns period) & Power-on Reset Logic       │
│  - DUT: updated_top_module2                                            │
│  - Background AXI4-Lite Protocol & Handshake Monitor                   │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                      riscv_transaction                         │   │
│   │   Stimulus program bytes, cycle budgets, expected architectural│   │
│   │   registers, memory contents, GPIO in/out, and timer pulses    │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v (gen2drv mailbox)                 │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                       riscv_generator                          │   │
│   │   Generates 11 directed tests covering core instructions,      │   │
│   │   peripheral AXI writes, and peripheral AXI readbacks          │   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v                                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                         driver                                 │   │
│   │   Backdoor memory initialization, hardware reset pulsing,      │   │
│   │   GPIO input driving, and clock stepping                       │   │
│   └───────────────┬────────────────────────────────┬───────────────┘   │
│                   │ (drv2mon mailbox)              ^                   │
│                   v                                │ (mon2drv done)    │
│   ┌────────────────────────────────────────────────┴───────────────┐   │
│   │                         monitor                                │   │
│   │   Samples register file x1..x31, local SRAM, and PWM/GPIO state│   │
│   └────────────────────────────────┬───────────────────────────────┘   │
│                                    v (mon2scb mailbox)                 │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                        scoreboard                              │   │
│   │   Compares sampled DUT results against golden reference values;│   │
│   │   tracks total pass/fail assertions and produces summary report│   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### Test Suites & Coverage Matrix

| Test ID | Test Objective | Stimulus / Operations | Checked Registers / Assertions | Verdict |
| :---: | :--- | :--- | :--- | :---: |
| **TEST 1** | **Reset Verification** | Power-on reset sequence | `x1..x5, x10, x15, x31 == 0` | **PASS** |
| **TEST 2** | **R-Type ALU** | `add`, `sub`, `and`, `or`, `xor`, `slt` | `x1..x8` ALU results | **PASS** |
| **TEST 3** | **I-Type ALU** | `addi`, `andi`, `ori`, `xori`, `slti`, `slli`, `srli` | `x1..x7` immediate results | **PASS** |
| **TEST 4** | **Load & Store** | `sw` & `lw` through local data memory | `x1..x3`, `mem[0]` integrity | **PASS** |
| **TEST 5** | **Branch Taken** | `beq` skips instruction forward | `x1, x3, x4` PC redirect check | **PASS** |
| **TEST 6** | **Unconditional Jump** | `jal` target leap and link register save | `x1, x2, x3, x5 (PC+4)` | **PASS** |
| **TEST 7** | **AXI PWM Write & Read** | Write Period=100, Duty=25, Enable=1; Readback | `x6..x12`, PWM toggling | **PASS** |
| **TEST 8** | **Address Decode Boundary**| Local SRAM write vs. peripheral space isolation | `x1, x3, mem[0] == 123` | **PASS** |
| **TEST 9** | **AXI Timer Write & Read**| Write Compare=10, Enable=1; Readback | `x5, x6, x13..x15`, Timer pulse | **PASS** |
| **TEST 10**| **AXI GPIO Write & Read** | Write DIR=0xFF, OUT=0x55; Read IN=0xA5A55A5A | `x16..x19`, `gpio_out` check | **PASS** |
| **TEST 11**| **AXI UART Write & Read** | Write TX_DATA='Z' (0x5A); Read TX_STATUS | `x20, x21 == 0x5A` | **PASS** |

**Total Scoreboard Assertions: 58 PASSED, 0 FAILED (100% Pass Rate).**

### Race-Free Driver-Monitor Handshake
The modular layered testbench incorporates a bidirectional mailbox handshake (`drv2mon` and `mon2drv`). The driver runs the clock cycles for test $N$, passes the transaction to the monitor, and blocks until the monitor finishes sampling all architectural registers and memory locations. This prevents next-test memory clears or resets from altering state prematurely.

### Standalone Unit Testbenches
- **`tb_gpio.sv`**: Tests direction masking, output driving, input synchronization, and AXI write/read handshakes (**21 PASSED, 0 FAILED**).
- **`tb_uart.sv`**: Tests 8N1 frame format, start/stop bit validation, baud clock divider, AXI status flags, and full loopback transmission (**17 PASSED, 0 FAILED**).

---

## Physical Design & ASIC Synthesis

Targeted at a 100 MHz standard cell library using **Cadence Genus Synthesis Solution** and **Cadence Conformal LEC**.

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
| **Synthesis Tool** | Cadence Genus 26.10-p002_1 | Rocky Linux 9.8 |
| **Target Clock Frequency** | **100.0 MHz** ($T_{clk} = 10.0\text{ ns}$) | Real-time system clock |
| **Worst Setup Slack** | **+1130.6 ps** (+1.13 ns) | **MET** (Zero timing violations) |
| **Total Negative Slack (TNS)** | **0.0 ps** | All timing paths met |
| **Total Cell Area** | **$4675.14\ \mu\text{m}^2$** | Standard cell gate footprint |
| **Total Cell Count** | **1,852** instances | 287 Sequential, 1,565 Combinational |
| **Total Power Consumption** | **$90.68\ \mu\text{W}$** | @ $0.9\text{V}$, $125^\circ\text{C}$ (Worst-case PVT) |

### Logic Equivalence Checking (LEC)
Using **Cadence Conformal(R) LEC** (`Physical Design/capstone.do`):
- **Golden Model**: SystemVerilog RTL.
- **Revised Model**: Synthesized gate-level netlist.
- **Result**: **100% Compare Points Passed** with zero non-equivalences and zero unmapped points.

---

## Getting Started & Simulation

### Prerequisites
- **EDA Simulator**: QuestaSim / ModelSim (e.g. QuestaSim 2024.1).
- **FPGA Tooling**: Intel Quartus Prime Lite / Standard Edition 20.1+.
- **ASIC Tools (Optional)**: Cadence Genus & Conformal LEC.

---

### 1. Manual QuestaSim GUI Execution

1. Double-click **`verification/open_questa_gui.bat`** (or open QuestaSim &rarr; **File** &rarr; **Open** &rarr; **Project...** &rarr; choose `verification/riscv_soc.mpf`).
2. All 23 source files and testbenches will load with green checkmarks.
3. To run simulation:
   - Select **Simulate &rarr; Start Simulation...**
   - Expand library **`work`** and select **`top_tb`**.
   - In transcript, type:
     ```tcl
     add wave -r /*
     run -all
     ```
   - All 58 assertions will pass and waveforms will populate in the Wave window.

---

### 2. One-Click Batch Simulation Scripts

From Command Prompt or PowerShell inside `verification/`:

- **Modular SoC Layered Testbench (58 Tests)**:
  ```cmd
  run_questa_soc_modular.bat
  ```
- **SoC Layered Testbench with Waveform GUI**:
  ```cmd
  run_questa_gui_wave.bat
  ```
- **Standalone GPIO Unit Verification (21 Tests)**:
  ```cmd
  run_questa_gpio.bat
  ```
- **Standalone UART Unit Verification (17 Tests)**:
  ```cmd
  run_questa_uart.bat
  ```

---

### 3. Intel Quartus Prime FPGA Synthesis

1. Open Intel Quartus Prime.
2. Select **File &rarr; Open Project...** and choose `verification/single_cycle_core.qpf`.
3. Press **Ctrl + L** (or click **Processing &rarr; Start Compilation**).
4. The project synthesizes cleanly targeting the Intel Cyclone V FPGA with 0 errors.

---

## Authors & Contributors

- **Wali Shajeeh**
- **Mufeez Rasheed Khan**
- **Muhammad Areeb**

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
