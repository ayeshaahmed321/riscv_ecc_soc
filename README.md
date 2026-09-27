# Functional Verification of an RV32I SoC with AMBA Peripherals

## Project Overview
* **Project Title:** Functional Verification of an RV32I SoC utilizing UVM and SVA
* **Team Members:** Ayesha Ahmed, Malaika Ghazanfar, Syeda Fatima Mehdvi
* **Project Objective:** To architect, implement, and rigorously verify a custom RISC-V System-on-Chip utilizing a hybrid verification strategy (UVM, SystemVerilog Assertions, and directed bare-metal testing) to achieve 100% functional coverage.
* **System Description:** The proposed system is a 32-bit architecture targeting FPGA implementation. An RV32I RISC-V CPU acts as the primary master, communicating through an AMBA matrix (AXI/APB) to an AXI-attached SRAM with SECDED ECC hardware, an APB motor controller with tachometer profiling and fail-safes, and an APB SPI Master.

## Directory Structure
* `/rtl`: Contains all SystemVerilog design source files (CPU, AMBA Matrix, Memory, Peripherals).
* `/verif`: Contains the UVM environments, sequences, agents, classes, SVA bindings, and testbenches (`tb_uvm_system_top.sv`, `tb_soc_top.sv`).
* `/filelists`: Contains `.f` files for batch compilation paths.
* `/reports`: Contains the detailed structural and functional text-based coverage reports for all test suites.

## Required Tools/Environment
* **Simulator:** QuestaSim / Questa Sim-64 (Tested on Version 2024.1)
* **Language:** SystemVerilog (IEEE 1800-2012)
* **Libraries:** UVM 1.1d (Built-in Questa package)

## How to Compile, Run, and Reproduce Results
The entire verification flow is executed directly via the QuestaSim Transcript. The commands below automatically compile the hardware with detailed structural coverage tracking (`+cover=bcesf`), compile assertions as a multi-file unit (`-mfcu`), execute the UVM/Directed tests, and export the highly detailed coverage reports.

1. Open QuestaSim and navigate to the project root directory.
2. Run the following command block in the Transcript to clean the environment and compile the design:

```tcl
# 1. Clean previous builds
quit -sim
vdel -all
vlib work

# 2. Compile Interfaces and RTL WITH Structural Coverage Tracking
vlog +cover=bcesf rtl/cpu_bus_if.sv rtl/ecc_mem_if.sv rtl/soc_if.sv
vlog +cover=bcesf rtl/ecc_encoder.sv rtl/ecc_decoder.sv rtl/sram_memory.sv rtl/fault_injector.sv
vlog +cover=bcesf rtl/axi_ecc_memory.sv rtl/apb_ecc_registers.sv
vlog +cover=bcesf rtl/amba_interconnect.sv rtl/apb_motor_ctrl.sv rtl/apb_spi_master.sv
vlog +cover=bcesf rtl/imem.sv rtl/rv32i_core.sv rtl/soc_top.sv

# 3. Compile Assertions, Packages, and Testbenches
vlog -mfcu -cuname sva_unit verif/core_assertions.sv verif/ecc_assertions.sv verif/motor_assertions.sv
vlog verif/cpu_bus_pkg.sv verif/ecc_mem_pkg.sv
vlog verif/tb_soc_top.sv verif/tb_uvm_top.sv verif/tb_uvm_system_top.sv


Run the following command blocks sequentially to execute the three verification environments and generate detailed .txt coverage reports:

# ---------------------------------------------------------
# Run System Bus UVM & Generate Detailed Coverage
# ---------------------------------------------------------
vsim -coverage -suppress 10717,12036 -voptargs=+acc work.tb_uvm_system_top work.sva_unit
run -all
coverage save temp_cpu.ucdb
vcover report -details -all -output reports/cpu_bus_coverage_detailed.txt temp_cpu.ucdb
file delete temp_cpu.ucdb

# ---------------------------------------------------------
# Run ECC Memory UVM & Generate Detailed Coverage
# ---------------------------------------------------------
vsim -coverage -suppress 10717,12036 -voptargs=+acc work.tb_uvm_top work.sva_unit
run -all
coverage save temp_ecc.ucdb
vcover report -details -all -output reports/ecc_mem_coverage_detailed.txt temp_ecc.ucdb
file delete temp_ecc.ucdb

# ---------------------------------------------------------
# Run Directed SoC & Generate Detailed Coverage
# ---------------------------------------------------------
vsim -coverage -suppress 10717,12036 -voptargs=+acc work.tb_soc_top work.sva_unit
run -all
coverage save temp_dir.ucdb
vcover report -details -all -output reports/directed_coverage_detailed.txt temp_dir.ucdb
file delete temp_dir.ucdb