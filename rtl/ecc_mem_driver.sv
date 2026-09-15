import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_driver extends uvm_driver #(ecc_mem_seq_item);
    `uvm_component_utils(ecc_mem_driver)

    // The physical wires to the hardware
    virtual ecc_mem_if vif;

    function new(string name = "ecc_mem_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Grab the physical wires from the configuration database
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Driver could not find the virtual interface!")
        end
    endfunction

    // The active factory loop
    task run_phase(uvm_phase phase);
        forever begin
            // 1. Get the randomized packet from the Sequence
            seq_item_port.get_next_item(req);
            
            // 2. Wait for the clock tick, then push the data onto the wires
            @(posedge vif.clk);
            vif.data_addr  <= req.addr;
            vif.core_wdata <= req.wdata;
            vif.core_we    <= req.we;
            vif.fault_mask <= req.fault_mask;
            
            // 3. Tell the Sequence we finished this packet
            seq_item_port.item_done();
        end
    endtask
endclass