import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ecc_mem_scoreboard)

    // The receiving port from the Monitor
    uvm_analysis_imp #(ecc_mem_seq_item, ecc_mem_scoreboard) ap_export;

    // A shadow memory array to track what *should* be on the SRAM shelves
    logic [31:0] shadow_mem [int];

    function new(string name = "ecc_mem_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_export = new("ap_export", this);
    endfunction

    // This function automatically runs every time the Monitor broadcasts a snapshot
    virtual function void write(ecc_mem_seq_item trans);
        if (trans.we) begin
            // 1. If it is a write, update our perfect shadow memory
            shadow_mem[trans.addr] = trans.wdata;
        end else begin
            // 2. If it is a read, calculate expectations
            int bits_flipped = $countones(trans.fault_mask); 
            logic [31:0] expected_data = shadow_mem.exists(trans.addr) ? shadow_mem[trans.addr] : 32'h0;

            // 3. Judge the hardware based on SECDED math rules
            if (bits_flipped == 1) begin
                if (trans.single_err !== 1'b1) `uvm_error("SCB", "FAILED: Missed Single Error!")
                if (trans.rdata !== expected_data) `uvm_error("SCB", "FAILED: Did not correct data!")
            end 
            else if (bits_flipped == 2) begin
                if (trans.double_err !== 1'b1) `uvm_error("SCB", "FAILED: Missed Double Error!")
            end 
            else if (bits_flipped == 0) begin
                if (trans.rdata !== expected_data) `uvm_error("SCB", "FAILED: Data corrupted with 0 faults!")
            end
        end
    endfunction
endclass