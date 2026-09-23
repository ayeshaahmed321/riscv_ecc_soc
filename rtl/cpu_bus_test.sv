import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_test extends uvm_test;
    `uvm_component_utils(cpu_bus_test)

    cpu_bus_env env;

    function new(string name = "cpu_bus_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cpu_bus_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        cpu_bus_sequence seq = cpu_bus_sequence::type_id::create("seq");
        phase.raise_objection(this);

        `uvm_info("TEST", "Starting System Bus Verification Sequence...", UVM_LOW)
        seq.start(env.agent.sqr);

        #2500ns; // margin for SPI shifting + the profile/stall-window waits inside the sequence
        phase.drop_objection(this);
    endtask
endclass