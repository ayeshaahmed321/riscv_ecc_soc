import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_seq_item extends uvm_sequence_item;
    // Randomized Stimulus (Inputs to the memory)
    rand logic [31:0] addr;
    rand logic [31:0] wdata;
    rand logic        we;
    rand logic [38:0] fault_mask;

    // Captured Responses (Outputs from the memory)
    logic [31:0] rdata;
    logic        single_err;
    logic        double_err;

    `uvm_object_utils_begin(ecc_mem_seq_item)
        `uvm_field_int(addr,       UVM_ALL_ON)
        `uvm_field_int(wdata,      UVM_ALL_ON)
        `uvm_field_int(we,         UVM_ALL_ON)
        `uvm_field_int(fault_mask, UVM_ALL_ON)
        `uvm_field_int(rdata,      UVM_ALL_ON)
        `uvm_field_int(single_err, UVM_ALL_ON)
        `uvm_field_int(double_err, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ecc_mem_seq_item");
        super.new(name);
    endfunction

    // Constrain the randomized addresses strictly to the SRAM space (0x00 to 0xFC)
    constraint addr_c {
        addr inside {[32'h0000_0000 : 32'h0000_00FC]};
    }

constraint fault_c {
    $countones(fault_mask) <= 2;
}
endclass