import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_driver extends uvm_driver #(ecc_mem_seq_item);
    `uvm_component_utils(ecc_mem_driver)
    virtual ecc_mem_if vif;

    function new(string name = "ecc_mem_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(virtual ecc_mem_if)::get(this, "", "vif", vif);
    endfunction

    task run_phase(uvm_phase phase);
        // Default inactive state for all buses
        vif.awvalid <= 0; vif.wvalid <= 0; vif.bready <= 0;
        vif.arvalid <= 0; vif.rready <= 0;
        vif.psel <= 0; vif.penable <= 0;

        forever begin
            seq_item_port.get_next_item(req);

            // 1. APB Phase: Write the randomized fault mask to 0x100
            @(posedge vif.clk);
            vif.paddr <= 32'h0000_0100;
            vif.pwdata <= req.fault_mask;
            vif.pwrite <= 1'b1;
            vif.psel <= 1'b1;
            vif.penable <= 1'b0;
            @(posedge vif.clk);
            vif.penable <= 1'b1; // Setup phase complete, enable access
            do @(posedge vif.clk); while (!vif.pready);
            vif.psel <= 1'b0;
            vif.penable <= 1'b0;

            // 2. AXI Phase: Read or Write the SRAM
            if (req.we) begin
                // AXI Write Handshake
                vif.awaddr <= req.addr;  vif.wdata <= req.wdata;
                vif.awvalid <= 1'b1;     vif.wvalid <= 1'b1;     vif.bready <= 1'b1;
                
                do @(posedge vif.clk); while (!(vif.awready && vif.wready));
                vif.awvalid <= 1'b0;     vif.wvalid <= 1'b0;
                
                do @(posedge vif.clk); while (!vif.bvalid);
                vif.bready <= 1'b0;
            end else begin
                // AXI Read Handshake
                vif.araddr <= req.addr;  vif.arvalid <= 1'b1;    vif.rready <= 1'b1;
                
                do @(posedge vif.clk); while (!vif.arready);
                vif.arvalid <= 1'b0;
                
                do @(posedge vif.clk); while (!vif.rvalid);
                vif.rready <= 1'b0;
            end
            
            seq_item_port.item_done();
        end
    endtask
endclass