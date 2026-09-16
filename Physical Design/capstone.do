set log file capstone_lec.log -replace

// Read timing libraries
read library ../lib/slow_vdd1v0_basicCells.lib -liberty -both
read library ../lib/ram_256x16A_fast_syn.lib -liberty -both -append

// Read Golden RTL
read design ../rtl/*.sv -sv -golden
set root module updated_top_module2 -golden

// Declare Blackboxes
add black box ram_256x16A

// Read Revised Netlist
read design ../synthesis/outputs/updated_top_module2_netlist.v -verilog -revised
set root module updated_top_module2 -revised

// Set undriven signal behavior (0 = tied to 0, Z = high-Z)
set undriven signal 0 -golden
set undriven signal 0 -revised


// Switch to LEC mode and compare
set system mode lec
add compared point -all
compare
