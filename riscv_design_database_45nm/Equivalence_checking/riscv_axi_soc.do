set log file riscv_axi_soc_lec.log -replace

// Read standard cell library
read library ../lib/slow_vdd1v0_basiccells.v -verilog -both

// Declare memory modules as black boxes BEFORE reading designs
// These are SRAM macros, not synthesized to standard cells
add black box instr_mem -both
add black box data_mem -both

// Read Golden RTL
read design ../rtl/*.sv -sv -golden
set root module updated_top_module2 -golden

// Read Revised Netlist
read design ../synthesis/outputs/updated_top_module2_netlist.v -verilog -revised
set root module updated_top_module2 -revised

// Set undriven signal behavior (tied to 0)
set undriven signal 0 -both

// Switch to LEC mode and compare
set system mode lec
add compared point -all
compare

// Generate detailed equivalence reports
report compare data -all > compare_all.rpt
report unmapped points > unmapped.rpt
