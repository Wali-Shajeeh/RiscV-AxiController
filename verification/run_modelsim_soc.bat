@echo off
REM ============================================================================
REM  ModelSim Run Script for RISC-V SoC Layered Testbench
REM ============================================================================

set MODELSIM_PATH=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

set RTL_DIR=..\single_cycle_core_Mufeez_restored

if exist work rmdir /s /q work
vlib work

echo [INFO] Compiling RTL and Layered Testbench in ModelSim...
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
vsim -c -do "run -all; quit -f" work.tb_top

echo [INFO] Done.
