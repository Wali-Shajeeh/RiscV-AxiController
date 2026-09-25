# ==============================================================================
# Cadence Genus Synthesis Script for RISC-V AXI SoC
# Top Module: updated_top_module2
# ==============================================================================

set DESIGN "updated_top_module2"

# ------------------------------------------------------------------------------
# 1. Directories & Setup
# ------------------------------------------------------------------------------
file mkdir reports
file mkdir outputs

# NOTE: Update LIB_PATH and TARGET_LIBS with your university/foundry PDK .lib paths
set_db init_lib_search_path { . /path/to/pdk/libraries/ }
# Example target library (replace with your actual stdcell .lib, e.g. slow.lib or typical.lib)
# set_db target_library { slow.lib }
# set_db link_library   { * slow.lib }

# ------------------------------------------------------------------------------
# 2. Read SystemVerilog RTL Files
# ------------------------------------------------------------------------------
set_db hdl_error_on_blackbox true

read_hdl -language sv {
    alu.sv
    alu_control.sv
    axi_adapter.sv
    axi_interconnect.sv
    data_mem.sv
    decoder.sv
    imm_gen.sv
    instr_mem.sv
    pc_control.sv
    pc_reg.sv
    pwm_peripheral.sv
    reg_file.sv
    riscv_core.sv
    riscv_core_final.sv
    timer_peripheral.sv
    uart_regs.sv
    uart_rx.sv
    uart_tx.sv
    uart_peripheral.sv
    gpio_peripheral.sv
    updated_top_module2.sv
}

# ------------------------------------------------------------------------------
# 3. Elaborate Design
# ------------------------------------------------------------------------------
elaborate $DESIGN

check_design -unresolved > reports/check_design_unresolved.rpt

# ------------------------------------------------------------------------------
# 4. Constraints (SDC)
# ------------------------------------------------------------------------------
read_sdc constraints.sdc

# ------------------------------------------------------------------------------
# 5. Synthesis Steps (Generic -> Mapping -> Optimization)
# ------------------------------------------------------------------------------
syn_generic
syn_map
syn_opt

# ------------------------------------------------------------------------------
# 6. Generate Reports
# ------------------------------------------------------------------------------
report_timing > reports/timing.rpt
report_area   > reports/area.rpt
report_power  > reports/power.rpt
report_qor    > reports/qor.rpt

# ------------------------------------------------------------------------------
# 7. Write Outputs for Innovus P&R
# ------------------------------------------------------------------------------
write_hdl > outputs/${DESIGN}_synth.v
write_sdc > outputs/${DESIGN}_synth.sdc

puts "Synthesis Completed Successfully!"
