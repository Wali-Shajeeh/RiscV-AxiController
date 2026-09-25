set log file riscv_axi_soc_lec.log -replace

// Read standard cell library
read library ../lib/slow_vdd1v0_basiccells.v -verilog -both

// Read Golden RTL
read design ../rtl/*.sv -sv -golden
set root module updated_top_module2 -golden

// Declare memory modules as black boxes (they are SRAM macros, not synthesized)
add black box instr_mem
add black box data_mem

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
