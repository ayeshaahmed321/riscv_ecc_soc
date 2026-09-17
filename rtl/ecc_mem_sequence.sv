import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_seq_item extends uvm_sequence_item;
    // --- 1. Bus Tracking Fields ---
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        we;

    // --- 2. CPU & ECC Status Telemetry ---
    logic [31:0] pc;
    logic        cpu_stall;
    logic [38:0] fault_mask;
    logic        single_err;
    logic        double_err;

    // --- 3. New Peripheral Telemetry ---
    logic        spi_mosi;
    logic        spi_miso;
    logic        spi_sclk;
    logic        pwm_out;
    logic        rpm_pulse_in;
    logic        wdog_reset_out;

    // UVM Automation Macros for clean printing/cloning
    `uvm_object_utils_begin(ecc_mem_seq_item)
        `uvm_field_int(addr,           UVM_ALL_ON)
        `uvm_field_int(wdata,          UVM_ALL_ON)
        `uvm_field_int(rdata,          UVM_ALL_ON)
        `uvm_field_int(we,             UVM_ALL_ON)
        `uvm_field_int(pc,             UVM_ALL_ON)
        `uvm_field_int(cpu_stall,      UVM_ALL_ON)
        `uvm_field_int(fault_mask,     UVM_ALL_ON)
        `uvm_field_int(single_err,     UVM_ALL_ON)
        `uvm_field_int(double_err,     UVM_ALL_ON)
        `uvm_field_int(spi_mosi,       UVM_ALL_ON)
        `uvm_field_int(spi_miso,       UVM_ALL_ON)
        `uvm_field_int(spi_sclk,       UVM_ALL_ON)
        `uvm_field_int(pwm_out,        UVM_ALL_ON)
        `uvm_field_int(rpm_pulse_in,   UVM_ALL_ON)
        `uvm_field_int(wdog_reset_out, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ecc_mem_seq_item");
        super.new(name);
    endfunction
endclass
