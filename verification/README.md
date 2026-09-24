# RISC-V SoC with AXI4-Lite Peripheral Subsystem — Combined Quartus & Verification Project

This folder contains the complete, self-contained **Quartus Prime Project** combining both the synthesizable **RTL design** (`updated_top_module2`) and the industry-standard **Layered SystemVerilog Testbench** suite with **QuestaSim** simulation support.

---

## 1. Quartus Project Overview

- **Project File**: `single_cycle_core.qpf`
- **Settings File**: `single_cycle_core.qsf`
- **Target FPGA**: Intel Cyclone V (`5CGXFC7D6F31I7`)
- **Top-Level Entity**: `updated_top_module2`
- **EDA Simulation Tool**: QuestaSim (SystemVerilog)
- **NativeLink Testbench**: `top_tb` (Modular Layered Testbench)

You can open `single_cycle_core.qpf` directly in Quartus Prime (GUI or CLI).

---

## 2. Directory Contents

### A. Synthesizable RTL Files
| File | Description |
| :--- | :--- |
| **`updated_top_module2.sv`** | **Top-level entity** integrating RISC-V processor core, AXI4-Lite master adapter, crossbar interconnect, PWM, Timer, GPIO, and UART peripherals. |
| **`riscv_core.sv`**, **`riscv_core_final.sv`** | RV32I processor core datapath and control wiring. |
| **`alu.sv`**, **`alu_control.sv`** | 32-bit ALU and ALU control decoder. |
| **`imm_gen.sv`** | Immediate generation unit supporting I, S, B, U, J instruction formats. |
| **`reg_file.sv`** | 32 x 32-bit register file (x0 hardwired to 0). |
| **`pc_reg.sv`**, **`pc_control.sv`** | Program counter register with synchronous stall support and branch/jump target logic. |
| **`decoder.sv`** | Main control unit decoder for RV32I opcodes. |
| **`instr_mem.sv`**, **`data_mem.sv`** | Memory subsystems supporting behavioral simulation arrays as well as synthesized FPGA RAM/ROM. |
| **`axi_adapter.sv`** | Bridges RISC-V memory-mapped load/store bus to AXI4-Lite protocol. |
| **`axi_interconnect.sv`** | 1-Master to multi-slave crossbar interconnect routing based on address map (`0x4000_0000+`). |
| **`pwm_peripheral.sv`** | Memory-mapped AXI4-Lite PWM peripheral (Period, Duty Cycle, Enable registers). |
| **`timer_peripheral.sv`** | Memory-mapped AXI4-Lite Timer peripheral with compare match and overflow output. |
| **`gpio_peripheral.sv`** | Memory-mapped AXI4-Lite GPIO peripheral (DIR, OUT, IN registers) with bitmasking. |
| **`uart_tx.sv`** | 8N1 UART serial transmitter with parameterizable baud rate and clock divider. |
| **`uart_rx.sv`** | 8N1 UART serial receiver with 2-FF synchronizer and mid-bit sampling. |
| **`uart_regs.sv`** | AXI4-Lite UART register controller with TX_DATA, TX_STATUS, RX_DATA, RX_STATUS. |
| **`uart_peripheral.sv`** | Top-level AXI4-Lite UART peripheral wrapper integrating TX, RX, and register block. |
| **`instr_rom2.v`**, **`data_ram.v`** | Intel FPGA IP memory blocks (`.qip`, `.bb.v`). |
| **`hex_file.hex`**, **`mif_file.mif`** | Memory initialization images. |
| **`add_three_numbers.sdc`** | Timing constraints file. |

### B. Layered Testbench & Verification Files
| File | Layer | Description |
| :--- | :--- | :--- |
| **`soc_intf.sv`** | Interface | Encapsulates `clk`, `reset`, `pwm_out`, `timer_overflow`, `gpio_out`, `gpio_in`, `uart_tx`, and `uart_rx` pins. |
| **`transaction.sv`** | Transaction | Verification transaction object storing test program instructions, runtime cycles, GPIO inputs/outputs, timer overflow, and expected register/memory states. |
| **`generator.sv`** | Generator | Generates 11 comprehensive directed test cases covering reset, R-type, I-type, Load/Store, Branch, JAL, AXI PWM, Address Decode, AXI Timer, AXI GPIO, and AXI UART. |
| **`driver.sv`** | Driver | Handles reset asserting, backdoor loads instruction/data memory, drives GPIO inputs, monitors timer overflow pulses, drives clock ticks, and forwards transaction to monitor. |
| **`monitor.sv`** | Monitor | Samples architectural register state (`x1`..`x31`), data memory locations, and PWM output. |
| **`scoreboard.sv`** | Scoreboard | Compares observed DUT state against golden reference expectations (registers, memory, PWM, GPIO output, timer overflow) and generates verification report. |
| **`environment.sv`** | Environment | Connects generator, driver, monitor, and scoreboard via SystemVerilog mailboxes (`gen2drv`, `drv2mon`, `mon2scb`). |
| **`top_tb.sv`** | Test Top | Top simulation module: instantiates DUT (`updated_top_module2`), generates clock, monitors AXI bus activity, and runs environment. |
| **`tb_gpio.sv`** | GPIO Unit TB | Comprehensive unit and integration testbench verifying DIR, OUT, IN registers, masking, and AXI handshakes (21 assertions). |
| **`tb_uart.sv`** | UART Unit TB | Comprehensive unit and integration testbench verifying TX, RX, AXI register access, and full loopback (17 assertions). |
| **`instructions_test.hex`** | Test Stimulus | 22-instruction RV32I validation assembly binary. |
| **`pwm_test.hex`** | Test Stimulus | Memory-mapped AXI program for PWM testing (Period = 100, Duty = 25, Enable = 1). |

### C. Simulation Scripts
| Script | Description |
| :--- | :--- |
| **`open_questa_gui.bat`** | Launches QuestaSim GUI directly with `riscv_soc.mpf` project loaded. |
| **`run_questa_gui_wave.bat`** | Launches QuestaSim GUI, loads `top_tb`, adds waveforms, and runs simulation. |
| **`run_questa_soc_modular.bat`** | One-click script to compile local RTL and modular testbench (`top_tb.sv`) and execute in **QuestaSim** CLI (58 PASSED). |
| **`run_questa_gpio.bat`** | One-click script to compile and run standalone GPIO verification in **QuestaSim** (21 PASSED). |
| **`run_questa_uart.bat`** | One-click script to compile and run standalone UART verification in **QuestaSim** (17 PASSED). |

---

## 3. How to Run

### Option 1: One-Click QuestaSim Simulation (Command Line)
Double-click or run from PowerShell / Command Prompt inside `verification/`:
```bat
run_questa_soc_modular.bat
```
Output:
```
==========================================================
  RISC-V SoC — Modular Layered Directed Testbench
  DUT: updated_top_module2 (single-cycle + AXI + PWM + Timer + GPIO + UART)
  Total Tests: 11
==========================================================
...
==========================================================
  AXI BUS SUMMARY
    Total AXI Writes completed: 8
    Total AXI Reads  completed: 7
==========================================================
  SCOREBOARD:  58 PASSED  |  0 FAILED
==========================================================
  >>> ALL TESTS PASSED <<<
==========================================================
```

### Option 2: Open & Run via QuestaSim GUI Project (Manual Mode)
1. Double-click **`open_questa_gui.bat`** (or open QuestaSim -> **File -> Open -> Project...** -> choose `verification/riscv_soc.mpf`).
2. In the **Project** tab, all RTL files and testbenches are already organized and compiled (green checkmarks).
3. To recompile everything manually: Right-click in Project window -> **Compile -> Compile All**.
4. To run simulation:
   - Go to top menu: **Simulate -> Start Simulation...**
   - Expand library **work** and select **`top_tb`** (Modular Layered Testbench).
   - Click **OK**.
   - In transcript, type:
     ```tcl
     add wave -r /*
     run -all
     ```
   - All 58 verification checks will run and pass, with live waveforms populated in the Wave window.

### Option 3: One-Click GUI Simulation with Live Waveforms
Double-click:
```bat
run_questa_gui_wave.bat
```
This automatically launches QuestaSim GUI, loads the design with full waveform visibility (`-voptargs=+acc`), adds all waves to the waveform viewer, and runs simulation to completion.

### Option 4: Open & Compile in Quartus Prime
1. Open Intel Quartus Prime.
2. Select **File -> Open Project...** and choose `verification/single_cycle_core.qpf`.
3. Click **Processing -> Start Compilation** (or press `Ctrl+L`).
4. To launch simulation from Quartus:
   - Select **Tools -> Run Simulation Tool -> RTL Simulation**.
   - Quartus will automatically invoke QuestaSim with the configured `top_tb` testbench.

