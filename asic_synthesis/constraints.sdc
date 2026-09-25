# ==============================================================================
# Timing Constraints for RISC-V AXI SoC (updated_top_module2)
# Target Frequency: 50 MHz (Period: 20.0 ns)
# ==============================================================================

# Clock Definition
create_clock -name clk -period 20.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.2 [get_clocks clk]

# Reset constraint
set_false_path -from [get_ports reset]

# IO Delays (typical 20-30% of clock period)
set_input_delay  4.0 -clock clk [remove_from_collection [all_inputs] [get_ports {clk reset}]]
set_output_delay 4.0 -clock clk [all_outputs]

# Driving cell and load constraints (can be customized per PDK standard cell)
# set_driving_cell -lib_cell INVX1 [all_inputs]
# set_load 0.05 [all_outputs]
