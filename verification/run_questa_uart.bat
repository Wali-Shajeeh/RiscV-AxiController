@echo off
REM ============================================================================
REM  QuestaSim Run Script — UART Subsystem Verification
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64
set PATH=%QUESTA_PATH%;%PATH%

if exist work rmdir /s /q work
vlib work

echo [INFO] Compiling UART SystemVerilog Modules and Testbench...
vlog -sv ^
  uart_tx.sv ^
  uart_rx.sv ^
  uart_regs.sv ^
  uart_peripheral.sv ^
  tb_uart.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Running UART Simulation in QuestaSim...
vsim -c -do "run -all; quit -f" work.tb_uart

echo [INFO] Done.
