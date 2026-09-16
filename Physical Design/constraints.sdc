# =============================================================
# Clock Definition
# =============================================================
create_clock -name clk -period 10 -waveform {0 5} [get_ports "clk"]

set_clock_transition -rise 0.1 [get_clocks "clk"]
set_clock_transition -fall 0.1 [get_clocks "clk"]
set_clock_uncertainty 0.01 [get_clocks "clk"]

# =============================================================
# Input Delays
# =============================================================
set_input_delay -max 1.0 [get_ports "reset"] -clock [get_clocks "clk"]

# =============================================================
# Output Delays
# =============================================================
set_output_delay -max 1.0 [get_ports "pwm_out"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "timer_overflow"] -clock [get_clocks "clk"]
