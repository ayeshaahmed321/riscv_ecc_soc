import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_monitor extends uvm_monitor;
    `uvm_component_utils(ecc_mem_monitor)

    virtual ecc_mem_if vif;
    uvm_analysis_port #(ecc_mem_seq_item) ap;

    logic [31:0] cap_addr, cap_wdata;
    logic [38:0] cap_mask;

    function new(string name = "ecc_mem_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        cap_addr = '0;
        cap_wdata = '0;
        cap_mask = '0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get ecc_mem_if from config_db")
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_seq_item trans;

        forever begin
            @(posedge vif.clk);

            if (vif.psel && vif.penable && vif.pready && vif.pwrite) begin
                case (vif.paddr)
                    32'h0000_0100: cap_mask[31:0] = vif.pwdata;
                    32'h0000_0110: cap_mask[38:32] = vif.pwdata[6:0];
                    default: ;
                endcase
            end

            if (vif.awvalid && vif.awready)
                cap_addr = vif.awaddr;
            if (vif.wvalid && vif.wready)
                cap_wdata = vif.wdata;

            if (vif.bvalid && vif.bready) begin
                trans = ecc_mem_seq_item::type_id::create("trans");
                trans.we         = 1'b1;
                trans.addr       = cap_addr;
                trans.wdata      = cap_wdata;
                trans.fault_mask = cap_mask;
                ap.write(trans);
            end

            if (vif.arvalid && vif.arready)
                cap_addr = vif.araddr;

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
