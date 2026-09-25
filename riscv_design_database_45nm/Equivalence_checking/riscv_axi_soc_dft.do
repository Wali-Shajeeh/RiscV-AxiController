set log file riscv_axi_soc_dft_lec.log -replace

// Read standard cell library
read library ../lib/slow_vdd1v0_basiccells.v -verilog -both

// Read Golden RTL
read design ../rtl/*.sv -sv -golden
set root module updated_top_module2 -golden

// Declare memory modules as black boxes
add black box instr_mem
add black box data_mem

// Read Revised DFT Netlist
read design ../synthesis/outputs_dft/updated_top_module2_netlist_dft.v -verilog -revised
set root module updated_top_module2 -revised

// Add DFT pin constraints and ignore scan ports
add pin constraints 0 SE -revised
add ignored inputs scan_in -revised
add ignored outputs scan_out -revised

// Set undriven signal behavior
set undriven signal 0 -both

// Switch to LEC mode and compare
set system mode lec
add compared point -all
compare

// Generate detailed equivalence reports
report compare data -all > compare_all_dft.rpt
report unmapped points > unmapped_dft.rpt
