@echo off
REM ============================================================================
REM  QuestaSim Run Script — RISC-V SoC Modular Layered Testbench
REM ============================================================================
REM  Compiles the local RTL and modular testbench files, then runs simulation.
REM  Files compiled:
REM    RTL:  alu, alu_control, imm_gen, reg_file, pc_reg, instr_mem, data_mem,
REM          decoder, pc_control, axi_adapter, axi_interconnect, pwm_peripheral,
REM          timer_peripheral, updated_top_module2
REM    TB:   soc_intf.sv  (interface)
REM          top_tb.sv    (includes environment -> all class files via `include)
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64
set PATH=%QUESTA_PATH%;%PATH%

if exist work rmdir /s /q work
vlib work

echo [INFO] Compiling RTL and Modular Layered Testbench...
vlog -sv ^
  alu.sv ^
  alu_control.sv ^
  imm_gen.sv ^
  reg_file.sv ^
  pc_reg.sv ^
  instr_mem.sv ^
  data_mem.sv ^
  decoder.sv ^
  pc_control.sv ^
  axi_adapter.sv ^
  axi_interconnect.sv ^
  pwm_peripheral.sv ^
  timer_peripheral.sv ^
  uart_tx.sv ^
  uart_rx.sv ^
  uart_regs.sv ^
  uart_peripheral.sv ^
  gpio_peripheral.sv ^
  updated_top_module2.sv ^
  soc_intf.sv ^
  top_tb.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Running Simulation...
vsim -c -do "log -r /*; run -all; quit -f" work.top_tb

echo [INFO] Done.
