import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_mem_monitor)

    // NOTE: tb_uvm_top.sv instantiates and config_db::sets a `ecc_mem_if`
    // (not `soc_if`). Monitor must request the SAME type or uvm_config_db::get
    // silently fails to match and fatals. ecc_mem_if also has no clocking
    // block and no `pc` field, so plain @(posedge vif.clk) sampling is used.
    virtual ecc_mem_if vif;
    uvm_analysis_port #(ecc_mem_seq_item) ap;

    function new(string name = "ecc_mem_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_seq_item trans;
        logic [31:0] cap_addr, cap_wdata;
        logic [38:0] cap_mask;

        forever begin
            @(posedge vif.clk);

            // Snoop APB: capture the fault mask write to 0x100
            if (vif.psel && vif.penable && vif.pready && vif.pwrite) begin
                if (vif.paddr == 32'h0000_0100) begin
                    cap_mask = {7'b0, vif.pwdata};
                end
            end

            // Snoop AXI Write Channel
            if (vif.awvalid && vif.awready) cap_addr  = vif.awaddr;
            if (vif.wvalid  && vif.wready)  cap_wdata = vif.wdata;

            // Broadcast AXI Write Transaction once complete
            if (vif.bvalid && vif.bready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we         = 1'b1;
                trans.addr       = cap_addr;
                trans.wdata      = cap_wdata;
                trans.fault_mask = cap_mask;
                ap.write(trans);
            end

            // Snoop AXI Read Channel
            if (vif.arvalid && vif.arready) cap_addr = vif.araddr;

            // Broadcast AXI Read Transaction once complete
            if (vif.rvalid && vif.rready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we         = 1'b0;
                trans.addr       = cap_addr;
                trans.rdata      = vif.rdata;
                trans.fault_mask = cap_mask;
                trans.single_err = vif.single_err;
                trans.double_err = vif.double_err;
                ap.write(trans);
            end
        end
    endtask
endclass
