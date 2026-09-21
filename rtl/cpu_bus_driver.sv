import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_driver extends uvm_driver #(cpu_bus_seq_item);
    `uvm_component_utils(cpu_bus_driver)
    virtual cpu_bus_if vif;

    function new(string name = "cpu_bus_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(virtual cpu_bus_if)::get(this, "", "vif", vif));
    endfunction

    task run_phase(uvm_phase phase);
        // Default inactive state
        vif.req <= 1'b0; 
        vif.we  <= 1'b0;

        forever begin
            seq_item_port.get_next_item(req);
            
            // 1. Assert CPU memory request
            @(posedge vif.clk);
            vif.req   <= 1'b1;
            vif.addr  <= req.addr;
            vif.we    <= req.we;
            if (req.we) vif.wdata <= req.wdata;

            // 2. Wait for the interconnect to complete the AMBA handshake
            do begin
                @(posedge vif.clk);
            end while (vif.stall);

            // 3. Drop request and capture any read data
            vif.req <= 1'b0;
            if (!req.we) req.rdata = vif.rdata;
            
            seq_item_port.item_done();
        end
    endtask
endclass