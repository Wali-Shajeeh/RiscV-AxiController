@echo off
set MODELSIM_PATH=C:\intelFPGA_lite\20.1\modelsim_ase\win32aloem
set PATH=%MODELSIM_PATH%;%PATH%

if exist work rmdir /s /q work
vlib work
vlog -sv alu.sv alu_control.sv imm_gen.sv reg_file.sv pc_reg.sv instr_mem.sv data_mem.sv controller_fsm.sv axi_adapter.sv axi_interconnect.sv pwm_peripheral.sv riscv_soc_mc.sv tb_riscv_soc_mc.sv
vsim -c -do "vcd file wave.vcd; vcd add -r /tb_riscv_soc_mc/*; run -all; quit -f" work.tb_riscv_soc_mc
