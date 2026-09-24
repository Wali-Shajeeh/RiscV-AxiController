@echo off
REM ============================================================================
REM  Launch QuestaSim GUI with riscv_soc.mpf Project
REM ============================================================================

set QUESTA_PATH=C:\questasim64_2024.1\win64

if not exist "%QUESTA_PATH%\vsim.exe" (
    echo [ERROR] QuestaSim not found at %QUESTA_PATH%
    pause
    exit /b 1
)

echo [INFO] Opening QuestaSim GUI with riscv_soc.mpf...
cd /d "%~dp0"
start "" "%QUESTA_PATH%\vsim.exe" riscv_soc.mpf
