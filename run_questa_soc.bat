@echo off
REM ============================================================================
REM  QuestaSim Run Script for RISC-V SoC Layered Testbench
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64
set PATH=%QUESTA_PATH%;%PATH%

set RTL_DIR=..\single_cycle_core_Mufeez_restored

if exist work rmdir /s /q work
vlib work

echo [INFO] Compiling RTL and Layered Testbench...
vlog -sv ^
  %RTL_DIR%\alu.sv ^
  %RTL_DIR%\alu_control.sv ^
  %RTL_DIR%\imm_gen.sv ^
  %RTL_DIR%\reg_file.sv ^
  %RTL_DIR%\pc_reg.sv ^
  %RTL_DIR%\instr_mem.sv ^
  %RTL_DIR%\data_mem.sv ^
  %RTL_DIR%\decoder.sv ^
  %RTL_DIR%\pc_control.sv ^
  %RTL_DIR%\axi_adapter.sv ^
  %RTL_DIR%\axi_interconnect.sv ^
  %RTL_DIR%\pwm_peripheral.sv ^
  %RTL_DIR%\updated_top_module2.sv ^
  tb_soc_layered.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Running Simulation...
vsim -c -do "log -r /*; run -all; quit -f" work.tb_top

echo [INFO] Done.
