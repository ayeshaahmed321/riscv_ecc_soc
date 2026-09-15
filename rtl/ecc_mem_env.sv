import uvm_pkg::*;
`include "uvm_macros.svh"

// 1. Agent Component
class ecc_mem_agent extends uvm_agent;
    `uvm_component_utils(ecc_mem_agent)

    uvm_sequencer #(ecc_mem_seq_item) sqr;
    ecc_mem_driver                    drv;
    ecc_mem_monitor                   mon;

    function new(string name = "ecc_mem_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(ecc_mem_seq_item)::type_id::create("sqr", this);
        drv = ecc_mem_driver::type_id::create("drv", this);
        mon = ecc_mem_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// 2. Environment Component
class ecc_mem_env extends uvm_env;
    `uvm_component_utils(ecc_mem_env)

    ecc_mem_agent      agent;
    ecc_mem_scoreboard scb;

    function new(string name = "ecc_mem_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = ecc_mem_agent::type_id::create("agent", this);
        scb   = ecc_mem_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.ap.connect(scb.ap_export);
    endfunction
endclass