# RISC-V AXI Controller 45nm ASIC Flow Database

This database contains the complete design files, standard cell libraries, timing constraints, and Cadence automation scripts for synthesis and formal equivalence checking of the **RISC-V AXI Controller SoC** (`updated_top_module2`).

---

## 1. Directory Structure

```text
riscv_design_database_45nm/
├── README.md                      # Flow guide and documentation
├── cshrc                          # Environment setup script for Cadence tools
├── lib/                           # 45nm standard cell timing libraries (.lib and .v models)
│   ├── slow_vdd1v0_basicCells.lib
│   ├── slow_vdd1v0_basiccells.v
│   ├── fast_vdd1v0_basicCells.lib
│   ├── fast_vdd1v0_basicCells.v
│   └── slow_corner.v
├── lef/                           # Physical LEF files (tech and macros)
│   ├── gsclib045_tech.lef
│   └── gsclib045_macro.lef
├── captable/                      # Capacitance tables for RC extraction
├── QRC_Tech/                      # Quantus RC extraction technology files
├── rtl/                           # 19 Synthesizable SystemVerilog RTL files
│   ├── alu.sv
│   ├── alu_control.sv
│   ├── axi_adapter.sv
│   ├── axi_interconnect.sv
│   ├── data_mem.sv
│   ├── decoder.sv
│   ├── gpio_peripheral.sv
│   ├── imm_gen.sv
│   ├── instr_mem.sv
│   ├── pc_control.sv
│   ├── pc_reg.sv
│   ├── pwm_peripheral.sv
│   ├── reg_file.sv
│   ├── timer_peripheral.sv
│   ├── uart_tx.sv
│   ├── uart_rx.sv
│   ├── uart_regs.sv
│   ├── uart_peripheral.sv
│   └── updated_top_module2.sv
├── constraints/                   # SDC timing constraints
│   └── constraints_top.sdc
├── synthesis/                     # Cadence Genus synthesis workspace
│   ├── genus_script.tcl           # Standard synthesis script
│   ├── genus_dft_script.tcl       # Scan chain insertion / DFT synthesis script
│   ├── clean.sh                   # Cleanup script
│   ├── outputs/                   # Netlists, SDCs, SDF delays
│   ├── outputs_dft/               # DFT netlists, scandef, ATPG libraries
│   └── reports/                   # Timing, Area, Power, QoR reports
├── Equivalence_checking/          # Cadence Conformal LEC workspace
│   ├── riscv_axi_soc.do           # LEC script (Golden RTL vs Synthesized Netlist)
│   ├── riscv_axi_soc_dft.do       # LEC script for DFT netlist verification
│   ├── libtov.do                  # Liberty-to-Verilog conversion script
│   └── clean.sh                   # LEC log and report cleanup script
├── physical_design/               # Innovus implementation workspace
└── STA/                           # Tempus signoff timing analysis workspace
```

---

## 2. Environment Setup

Before executing any Cadence tools on Linux, update the tool root paths in `cshrc` and source it:

```csh
source cshrc
```

Verify that `genus` and `lec` are available in your `$PATH`.

---

## 3. Running Synthesis (Cadence Genus)

### Standard Synthesis
Navigate to the `synthesis/` directory and execute:
```bash
cd synthesis
genus -f genus_script.tcl
```

Outputs produced:
- Netlist: `outputs/updated_top_module2_netlist.v`
- SDC: `outputs/updated_top_module2_sdc.sdc`
- SDF Delays: `outputs/delays.sdf`
- Reports: `reports/report_timing.rpt`, `reports/report_area.rpt`, `reports/report_power.rpt`, `reports/report_qor.rpt`

### DFT Synthesis (Scan Chain Insertion)
```bash
cd synthesis
genus -f genus_dft_script.tcl
```

Outputs produced:
- DFT Netlist: `outputs_dft/updated_top_module2_netlist_dft.v`
- ScanDEF: `outputs_dft/updated_top_module2_scanDEF.scandef`
- ATPG Verilog Library: exported to `lib/`

To clean synthesis outputs and logs:
```bash
bash clean.sh
```

---

## 4. Running Equivalence Checking (Cadence Conformal LEC)

### Verify Golden RTL vs Synthesized Netlist
Navigate to the `Equivalence_checking/` directory and run:
```bash
cd Equivalence_checking
lec -nogui -dofile riscv_axi_soc.do
```
(Or run `lec -gui -dofile riscv_axi_soc.do` for interactive GUI inspection).

Outputs produced:
- Comparison log: `riscv_axi_soc_lec.log`
- Full compare results: `compare_all.rpt`
- Unmapped points: `unmapped.rpt`

### Verify Golden RTL vs DFT Netlist
```bash
cd Equivalence_checking
lec -nogui -dofile riscv_axi_soc_dft.do
```

To clean LEC outputs and logs:
```bash
bash clean.sh
```
