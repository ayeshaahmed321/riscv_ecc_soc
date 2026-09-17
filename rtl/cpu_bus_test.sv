import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_test extends uvm_test;
    `uvm_component_utils(cpu_bus_test)
    
    uvm_sequencer #(cpu_bus_seq_item) sqr;
    cpu_bus_driver drv;

    function new(string name = "cpu_bus_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(cpu_bus_seq_item)::type_id::create("sqr", this);
        drv = cpu_bus_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

    task run_phase(uvm_phase phase);
        cpu_bus_sequence seq = cpu_bus_sequence::type_id::create("seq");
        phase.raise_objection(this);
        
        `uvm_info("TEST", "Starting System Bus Verification Sequence...", UVM_LOW)
        seq.start(sqr);
        
        #1500ns; // Give the SPI Master time to physically shift the bits
        phase.drop_objection(this);
    endtask
endclass