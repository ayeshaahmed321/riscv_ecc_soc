import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_mem_monitor)
    virtual ecc_mem_if vif;
    uvm_analysis_port #(ecc_mem_seq_item) ap;

    function new(string name = "ecc_mem_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif);
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_seq_item trans;
        logic [31:0] cap_addr, cap_wdata;
        logic [38:0] cap_mask;

        forever begin
            @(posedge vif.clk);
            #1; // Wait 1ns to sample stable signals
            
            // Snoop APB: Capture the fault mask
            if (vif.psel && vif.penable && vif.pready && vif.pwrite) cap_mask = vif.pwdata;
            
            // Snoop AXI: Capture Write Address and Data
            if (vif.awvalid && vif.awready) cap_addr = vif.awaddr;
            if (vif.wvalid &&  vif.wready)  cap_wdata = vif.wdata;
            
            // Broadcast AXI Write Transaction
            if (vif.bvalid && vif.bready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we = 1'b1;
                trans.addr = cap_addr;
                trans.wdata = cap_wdata;
                trans.fault_mask = cap_mask;
                ap.write(trans);
            end

            // Snoop AXI: Capture Read Address
            if (vif.arvalid && vif.arready) cap_addr = vif.araddr;
            
            // Broadcast AXI Read Transaction
            if (vif.rvalid && vif.rready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we = 1'b0;
                trans.addr = cap_addr;
                trans.rdata = vif.rdata;
                trans.fault_mask = cap_mask;
                trans.single_err = vif.single_err;
                trans.double_err = vif.double_err;
                ap.write(trans);
            end
        end
    endtask
endclass