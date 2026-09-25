# ==============================================================================
# Cadence Genus Synthesis Script for RISC-V AXI SoC
# Top Module: updated_top_module2
# Technology: 45nm standard cell (slow_vdd1v0_basicCells.lib)
# ==============================================================================

set DESIGN "updated_top_module2"

set_db init_lib_search_path ../lib/
set_db init_hdl_search_path ../rtl/
read_libs slow_vdd1v0_basicCells.lib

# Read all synthesizable SystemVerilog RTL files
read_hdl -sv {
    alu.sv
    alu_control.sv
    axi_adapter.sv
    axi_interconnect.sv
    data_mem.sv
    decoder.sv
    gpio_peripheral.sv
    imm_gen.sv
    instr_mem.sv
    pc_control.sv
    pc_reg.sv
    pwm_peripheral.sv
    reg_file.sv
    timer_peripheral.sv
    uart_tx.sv
    uart_rx.sv
    uart_regs.sv
    uart_peripheral.sv
    updated_top_module2.sv
}

elaborate $DESIGN
check_design -unresolved > reports/check_design_unresolved.rpt

read_sdc ../constraints/constraints_top.sdc

set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic
syn_map
syn_opt

# Reports
report_timing > reports/report_timing.rpt
report_power  > reports/report_power.rpt
report_area   > reports/report_area.rpt
report_qor    > reports/report_qor.rpt

# Outputs for P&R and Signoff
write_hdl > outputs/${DESIGN}_netlist.v
write_sdc > outputs/${DESIGN}_sdc.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > outputs/delays.sdf

puts "======================================================================"
puts "Genus Synthesis for $DESIGN completed successfully!"
puts "======================================================================"
