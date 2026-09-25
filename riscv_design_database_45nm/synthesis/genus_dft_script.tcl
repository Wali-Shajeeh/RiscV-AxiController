# ==============================================================================
# Cadence Genus DFT Synthesis Script for RISC-V AXI SoC
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
# NOTE: instr_mem.sv and data_mem.sv are EXCLUDED (black-boxed for SRAM macro replacement)
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
read_sdc ../constraints/constraints_top.sdc

# Mark memory black boxes as dont_touch to prevent optimization
set_dont_touch [get_cells *u_instr_mem*]
set_dont_touch [get_cells *u_data_mem*]

# DFT Configuration
set_db dft_scan_style muxed_scan
set_db dft_prefix dft_
define_test_signal -function shift_enable -name SE -active high -create_port SE
check_dft_rules

set_db syn_generic_effort medium
syn_generic
set_db syn_map_effort medium
syn_map
set_db syn_opt_effort medium

check_dft_rules
set_db design:${DESIGN} .dft_min_number_of_scan_chains 1
define_scan_chain -name top_chain -sdi scan_in -sdo scan_out -create_ports

# Remove assign statements and replace with buffer
set_db remove_assigns true
add_assign_buffer_options -ports scan_out -buffer_or_inverter BUFX20

connect_scan_chains -auto_create_chains
syn_opt

# Reports
report_scan_chains > reports/report_scan_chains.rpt
report_timing > reports/report_timing_dft.rpt
report_area   > reports/report_area_dft.rpt
report_power  > reports/report_power_dft.rpt

# Outputs for DFT, ATPG, and P&R
write_dft_atpg -library ../lib/slow_vdd1v0_basiccells.v
write_hdl > outputs_dft/${DESIGN}_netlist_dft.v
write_sdc > outputs_dft/${DESIGN}_sdc_dft.sdc
write_sdf -nonegchecks -edges check_edge -timescale ns -recrem split -setuphold split > outputs_dft/dft_delays.sdf
write_scandef > outputs_dft/${DESIGN}_scanDEF.scandef

puts "======================================================================"
puts "Genus DFT Synthesis for $DESIGN completed successfully!"
puts "======================================================================"
