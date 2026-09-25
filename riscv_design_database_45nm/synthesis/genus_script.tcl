# ==============================================================================
# Cadence Genus Synthesis Script for RISC-V AXI SoC
# Top Module: updated_top_module2
# Technology: 45nm standard cell (slow_vdd1v0_basicCells.lib)
# ==============================================================================

set DESIGN "updated_top_module2"

set_db init_lib_search_path ../lib/
set_db init_hdl_search_path ../rtl/

# Allow black boxes for memory modules (instr_mem, data_mem)
set_db hdl_error_on_blackbox false

read_libs slow_vdd1v0_basicCells.lib

# Read all synthesizable SystemVerilog RTL files
# NOTE: instr_mem.sv and data_mem.sv are EXCLUDED because they contain
#       large memory arrays (1024x32) and $readmemh which is simulation-only.
#       They are treated as black boxes and will be replaced with SRAM macros in P&R.
read_hdl -sv {
    alu.sv
    alu_control.sv
    axi_adapter.sv
    axi_interconnect.sv
    decoder.sv
    gpio_peripheral.sv
    imm_gen.sv
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

# Mark memory black boxes as dont_touch to prevent optimization
set_dont_touch [get_cells *u_instr_mem*]
set_dont_touch [get_cells *u_data_mem*]

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
