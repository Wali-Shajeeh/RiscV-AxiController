# ============================================================================
#  QuestaSim Project Setup Script — riscv_soc
# ============================================================================

# Open or create the project
if {[file exists "riscv_soc.mpf"]} {
    project open riscv_soc.mpf
} else {
    project new . riscv_soc
}

# Add all synthesizable RTL files
project addfile alu.sv
project addfile alu_control.sv
project addfile imm_gen.sv
project addfile reg_file.sv
project addfile pc_reg.sv
project addfile instr_mem.sv
project addfile data_mem.sv
project addfile decoder.sv
project addfile pc_control.sv
project addfile axi_adapter.sv
project addfile axi_interconnect.sv
project addfile pwm_peripheral.sv
project addfile timer_peripheral.sv
project addfile uart_tx.sv
project addfile uart_rx.sv
project addfile uart_regs.sv
project addfile uart_peripheral.sv
project addfile gpio_peripheral.sv
project addfile updated_top_module2.sv

# Add Layered Verification files
project addfile soc_intf.sv
project addfile top_tb.sv

# Add standalone testbenches
project addfile tb_gpio.sv
project addfile tb_uart.sv

# Calculate compile order and compile
project calculateorder
project compileall

project close
