# ==============================================================================
# SDC Timing Constraints for RISC-V AXI SoC (updated_top_module2)
# Target Frequency: 50 MHz (Period: 20.0 ns)
# Technology: 45nm Standard Cells
# ==============================================================================

# Clock Definition (50 MHz)
create_clock -name clk -period 20.0 -waveform {0 10} [get_ports "clk"]
set_clock_transition -rise 0.2 [get_clocks "clk"]
set_clock_transition -fall 0.2 [get_clocks "clk"]
set_clock_uncertainty 0.5 [get_clocks "clk"]

# Reset Constraint (Asynchronous / False Path)
set_false_path -from [get_ports "reset"]

# Input Delays
set_input_delay -max 2.0 [get_ports "uart_rx"] -clock [get_clocks "clk"]
set_input_delay -max 2.0 [get_ports "gpio_in*"] -clock [get_clocks "clk"]

# Output Delays
set_output_delay -max 2.0 [get_ports "pwm_out"] -clock [get_clocks "clk"]
set_output_delay -max 2.0 [get_ports "uart_tx"] -clock [get_clocks "clk"]
set_output_delay -max 2.0 [get_ports "gpio_out*"] -clock [get_clocks "clk"]
set_output_delay -max 2.0 [get_ports "timer_overflow"] -clock [get_clocks "clk"]
