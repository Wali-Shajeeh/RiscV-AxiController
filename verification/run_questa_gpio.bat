@echo off
REM ============================================================================
REM  QuestaSim Run Script — GPIO Subsystem Verification
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64
set PATH=%QUESTA_PATH%;%PATH%

if exist work rmdir /s /q work
vlib work

echo [INFO] Compiling GPIO SystemVerilog Module and Testbench...
vlog -sv ^
  gpio_peripheral.sv ^
  tb_gpio.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Running GPIO Simulation in QuestaSim...
vsim -c -do "run -all; quit -f" work.tb_gpio

echo [INFO] Done.
