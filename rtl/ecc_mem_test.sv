import uvm_pkg::*;
`include "uvm_macros.svh"

class ecc_mem_test extends uvm_test;
    `uvm_component_utils(ecc_mem_test)

    ecc_mem_env env;

    function new(string name = "ecc_mem_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ecc_mem_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        ecc_mem_sequence seq;
        seq = ecc_mem_sequence::type_id::create("seq");
        
        phase.raise_objection(this);
        // Start the randomized sequence!
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass