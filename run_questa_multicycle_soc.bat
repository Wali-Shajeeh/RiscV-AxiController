@echo off
REM ============================================================================
REM  QuestaSim Run Script for RISC-V Multicycle AXI SoC Testbench
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64
set PATH=%QUESTA_PATH%;%PATH%

set RTL_DIR=..\multicycle_axi_soc

if exist work rmdir /s /q work
vlib work

copy /Y pwm_test.hex hex_file.hex > nul

echo [INFO] Compiling Multicycle RTL and Testbench...
vlog -sv ^
  %RTL_DIR%\alu.sv ^
  %RTL_DIR%\alu_control.sv ^
  %RTL_DIR%\imm_gen.sv ^
  %RTL_DIR%\reg_file.sv ^
  %RTL_DIR%\pc_reg.sv ^
  %RTL_DIR%\instr_mem.sv ^
  %RTL_DIR%\data_mem.sv ^
  %RTL_DIR%\controller_fsm.sv ^
  %RTL_DIR%\axi_adapter.sv ^
  %RTL_DIR%\axi_interconnect.sv ^
  %RTL_DIR%\pwm_peripheral.sv ^
  %RTL_DIR%\riscv_soc_mc.sv ^
  tb_multicycle_soc.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Running Multicycle SoC Simulation...
vsim -c -do "log -r /*; run -all; quit -f" work.tb_riscv_soc_mc

echo [INFO] Done.
