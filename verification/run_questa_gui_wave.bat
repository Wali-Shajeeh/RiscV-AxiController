@echo off
REM ============================================================================
REM  Launch QuestaSim GUI and load Modular Layered Testbench with Waveforms
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64

if not exist "%QUESTA_PATH%\vsim.exe" (
    echo [ERROR] QuestaSim not found at %QUESTA_PATH%
    pause
    exit /b 1
)

cd /d "%~dp0"
echo [INFO] Launching QuestaSim GUI with top_tb and waveforms...
start "" "%QUESTA_PATH%\vsim.exe" -gui -do "vsim -voptargs=+acc work.top_tb; add wave -r /*; run -all"
