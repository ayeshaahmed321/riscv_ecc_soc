import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_mem_monitor)

    virtual ecc_mem_if vif;
    
    // The broadcasting port (like a megaphone) to send data to the Scoreboard
    uvm_analysis_port #(ecc_mem_seq_item) ap;

    function new(string name = "ecc_mem_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Monitor could not find the virtual interface!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_seq_item trans;
        
        forever begin
            // 1. Wait for the clock tick
            @(posedge vif.clk);
            #1; // Wait 1 tiny nanosecond to let the electrical signals settle
            
            // 2. Create a blank notepad
            trans = ecc_mem_seq_item::type_id::create("trans");
            
            // 3. Write down everything currently happening on the wires
            trans.addr       = vif.data_addr;
            trans.wdata      = vif.core_wdata;
            trans.we         = vif.core_we;
            trans.fault_mask = vif.fault_mask;
            trans.rdata      = vif.core_rdata;
            trans.single_err = vif.single_err;
            trans.double_err = vif.double_err;

            // 4. Broadcast the snapshot out of the megaphone
            ap.write(trans);
        end
    endtask
endclass