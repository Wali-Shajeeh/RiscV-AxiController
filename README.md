# RISC-V SoC with AXI4-Lite Peripheral Subsystem — Verification Suite

This folder contains the complete verification environment and layered testbenches for the RISC-V SoC capstone project.

---

## 1. Directory Contents

| File | Description |
| :--- | :--- |
| **`tb_soc_layered.sv`** | **Top Layered Testbench for Single-Cycle SoC (`updated_top_module2`)** with AXI4-Lite Interconnect and PWM Peripheral. |
| **`tb_single_cycle_core_layered.sv`** | Layered Testbench for the pure RV32I Single-Cycle Processor Core (`riscv_core`). |
| **`tb_multicycle_soc.sv`** | Testbench for the integrated **Multicycle RISC-V SoC** (`riscv_soc_mc`) with pure SystemVerilog memories and AXI PWM. |
| **`tb_multicycle_core.sv`** | Directed testbench for the standalone Multicycle RV32I Core. |
| **`run_questa_soc.bat`** | One-click QuestaSim script to compile and run the full SoC layered testbench. |
| **`run_questa_single_cycle_core.bat`** | One-click QuestaSim script for the single-cycle core layered testbench. |
| **`run_questa_multicycle_soc.bat`** | One-click QuestaSim script for the multicycle AXI SoC testbench. |
| **`run_modelsim_soc.bat`** | One-click ModelSim execution script for the SoC layered testbench. |
| **`hex_file.hex`** | Default instruction memory initialization file. |
| **`pwm_test.hex`** | Memory-mapped AXI program for PWM testing (Period = 100, Duty = 25, Enable = 1). |
| **`instructions_test.hex`** | Comprehensive 22-instruction RV32I validation sequence. |

---

## 2. Layered Testbench Architecture

The testbench strictly implements the industry-standard verification layers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                              tb_top                                    │
│  - Clock Generation (100 MHz, 10ns period)                            │
│  - Power-on Reset sequencing                                           │
│  - Background AXI handshake & protocol monitor                        │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                      riscv_transaction                         │   │
│   │   Scenario container: program hex, cycle count,                │   │
│   │   expected register file values, expected memory words,        │   │
│   │   peripheral checking flags                                    │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                │                                       │
│   ┌────────────────────────────▼───────────────────────────────────┐   │
│   │                       riscv_generator                          │   │
│   │   Constructs directed test transactions covering:              │   │
│   │   - Reset behavior                                             │   │
│   │   - R-type instructions                                        │   │
│   │   - I-type ALU instructions                                    │   │
│   │   - Load & Store instructions                                  │   │
│   │   - Conditional Branches (taken/not-taken)                     │   │
│   │   - Unconditional Jumps (JAL return address link)              │   │
│   │   - AXI boundary & peripheral mapping                          │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                │                                       │
│   ┌────────────────────────────▼───────────────────────────────────┐   │
│   │                       Driver (drive)                           │   │
│   │   - Asserts hardware reset                                     │   │
│   │   - Backdoor loads instruction & data memories via hierarchy  │   │
│   │   - Releases reset and drives clocks                           │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                │                                       │
│   ┌────────────────────────────▼───────────────────────────────────┐   │
│   │                       Checker (check)                          │   │
│   │   - Interrogates DUT internal registers (x1..x31)              │   │
│   │   - Validates memory contents against transaction expectations │   │
│   │   - Asserts pass/fail per checked register                     │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                │                                       │
│   ┌────────────────────────────▼───────────────────────────────────┐   │
│   │                         Scoreboard                             │   │
│   │   - Aggregates total pass/fail statistics                      │   │
│   │   - Summarizes AXI bus transactions (AW, W, B, AR, R)          │   │
│   │   - Emits final verification verdict                           │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                         DUT Instance                           │   │
│   │   updated_top_module2 / riscv_soc_mc                           │   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Test Suites & Verification Coverage

| Test | Name | Objectives Verified |
| :---: | :--- | :--- |
| **TEST 1** | **Reset Behavior** | Verifies all architectural registers (x1..x31) are initialized to `0x00000000` upon reset assertion. |
| **TEST 2** | **R-Type ALU** | Verifies `add`, `sub`, `and`, `or`, `xor`, and `slt` using register-to-register operations. |
| **TEST 3** | **I-Type ALU** | Verifies immediate operations: `addi`, `andi`, `ori`, `xori`, `slti`, `slli`, `srli`. |
| **TEST 4** | **Load/Store** | Verifies `sw` and `lw` to local data memory with data integrity checks. |
| **TEST 5** | **Branching** | Verifies `beq` branch resolution: correct PC redirect, instruction skipping, and sequential resumption. |
| **TEST 6** | **JAL** | Verifies unconditional jump: PC update and correct link address (`PC + 4`) stored to destination register. |
| **TEST 7** | **AXI Handshake & Boundary** | Verifies memory access to address `>= 0x4000_0000` triggers the `axi_adapter` rather than local SRAM. |
| **TEST 8** | **Address Decoding Boundary** | Verifies boundary separation: accesses `< 0x4000_0000` stay in local SRAM; peripheral registers are isolated. |

---

## 4. Key Verification Findings

1. **Single-Cycle AXI Stalling Defect (Mufeez design)**:
   - In `updated_top_module2`, when an AXI peripheral write occurs, `axi_adapter` enters `WRITE_ADDR` on the clock edge, raising `busy = 1`.
   - However, the `pc_reg` only captures the stall condition on the *subsequent* cycle.
   - This 1-cycle latency allows the PC to advance to the next instruction before stalling, which changes `alu_result` and prematurely drops `is_peripheral_access` mid-handshake.
2. **Multicycle Resolution (`multicycle_axi_soc`)**:
   - In our multicycle implementation, the FSM enters `S_MEMORY` and holds state, ALU controls, and operand multiplexers locked until `mem_ready == 1`.
   - Verified 100% working: PWM period (100) and duty cycle (25) were configured over AXI, and `pwm_out` toggled cleanly.

---

## 5. How to Run Simulations

### Using QuestaSim (Recommended):
Open a terminal in this directory (`c:\D_drive\Digital_Systems\DV\capstone\verification`) and execute:

```cmd
run_questa_soc.bat
```

Or run via PowerShell:
```powershell
$env:PATH = "C:\questasim64_2024.1\win64;" + $env:PATH
vlog -sv ..\single_cycle_core_Mufeez_restored\*.sv tb_soc_layered.sv
vsim -c -do "log -r /*; run -all; quit -f" work.tb_top
```

### Using ModelSim:
```cmd
run_modelsim_soc.bat
```
