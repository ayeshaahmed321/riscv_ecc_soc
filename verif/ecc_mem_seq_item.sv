import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_seq_item extends uvm_sequence_item;
    // --- 1. Bus Tracking Fields ---
    rand logic [31:0] addr;
    rand logic [31:0] wdata;
    logic [31:0]      rdata;
    rand logic        we;

    // Selects how many bits fault_mask will have set, with a distribution
    // weighted toward the 0/1/2-bit cases the spec actually asks us to
    // verify (single-bit correction, double-bit detection). A fully random
    // 39-bit mask would almost never land on exactly 0, 1, or 2 bits set.
    rand int unsigned fault_count_sel;
    constraint fault_count_dist_c {
        fault_count_sel dist { 0 := 25, 1 := 35, 2 := 35, 3 := 5 };
    }

    // --- 2. CPU & ECC Status Telemetry ---
    logic [31:0] pc;
    logic        cpu_stall;
    rand logic [38:0] fault_mask;

    // SRAM is 64 x 32-bit and the AXI address is byte based.
    // Keep UVM traffic inside the implemented 0x0000_0000-0x0000_00FC
    // memory window and aligned to 32-bit words.
    constraint addr_c {
        addr < 32'h0000_0100;
        addr[1:0] == 2'b00;
    }
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

    // Overrides the randomly-solved fault_mask with one that has EXACTLY
    // fault_count_sel bits set (0/1/2/3-5), at random positions in [0:38].
    // This is what actually makes single-bit-correction and double-bit-
    // detection scenarios reachable in a reasonable number of iterations.
    function void post_randomize();
        int n;
        int idx;
        logic [38:0] mask;

        case (fault_count_sel)
            0: n = 0;
            1: n = 1;
            2: n = 2;
            default: n = 3 + $urandom_range(2, 0); // 3..5 bits for "many"
        endcase

        mask = 39'h0;
        while ($countones(mask) < n) begin
            idx = $urandom_range(38, 0);
            mask[idx] = 1'b1;
        end
        fault_mask = mask;
    endfunction
endclass
