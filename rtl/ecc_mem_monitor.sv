import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_mem_monitor)
    
    // Updated to point to our unified virtual interface
    virtual soc_if vif;
    uvm_analysis_port #(ecc_mem_seq_item) ap;

    function new(string name = "ecc_mem_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Pull the unified interface from the configuration database
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_seq_item trans;
        logic [31:0] cap_addr, cap_wdata;
        logic [38:0] cap_mask;

        forever begin
            // FIXED: Wait on the clocking block edge for perfectly sampled values
            @(vif.cb);
            
            // Snoop APB: Capture the fault mask safely from the clocking block
            if (vif.cb.psel && vif.cb.penable && vif.cb.pready && vif.cb.pwrite) begin
                if (vif.cb.paddr == 32'h0000_0100) begin
                    cap_mask = {7'b0, vif.cb.pwdata};
                end
            end
            
            // Snoop AXI Write Channel
            if (vif.cb.awvalid && vif.cb.awready) cap_addr = vif.cb.awaddr;
            if (vif.cb.wvalid &&  vif.cb.wready)  cap_wdata = vif.cb.wdata;
            
            // Broadcast AXI Write Transaction once complete
            if (vif.cb.bvalid && vif.cb.bready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we         = 1'b1;
                trans.addr       = cap_addr;
                trans.wdata      = cap_wdata;
                trans.fault_mask = cap_mask;
                
                // Track current execution state for debugging context
                trans.pc         = vif.cb.pc; 
                ap.write(trans);
            end

            // Snoop AXI Read Channel
            if (vif.cb.arvalid && vif.cb.arready) cap_addr = vif.cb.araddr;
            
            // Broadcast AXI Read Transaction once complete
            if (vif.cb.rvalid && vif.cb.rready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we         = 1'b0;
                trans.addr       = cap_addr;
                trans.rdata      = vif.cb.rdata;
                trans.fault_mask = cap_mask;
                trans.single_err = vif.cb.single_err;
                trans.double_err = vif.cb.double_err;
                
                // Track current execution state for debugging context
                trans.pc         = vif.cb.pc; 
                ap.write(trans);
            end
        end
    endtask
endclass
