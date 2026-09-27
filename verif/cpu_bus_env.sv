class cpu_bus_agent extends uvm_agent;
    `uvm_component_utils(cpu_bus_agent)

    uvm_sequencer #(cpu_bus_seq_item) sqr;
    cpu_bus_driver                    drv;
    cpu_bus_monitor                   mon;

    function new(string name = "cpu_bus_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(cpu_bus_seq_item)::type_id::create("sqr", this);
        drv = cpu_bus_driver::type_id::create("drv", this);
        mon = cpu_bus_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class cpu_bus_env extends uvm_env;
    `uvm_component_utils(cpu_bus_env)

    cpu_bus_agent      agent;
    cpu_bus_scoreboard scb;
    cpu_bus_coverage   cov;

    function new(string name = "cpu_bus_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = cpu_bus_agent::type_id::create("agent", this);
        scb   = cpu_bus_scoreboard::type_id::create("scb", this);
        cov   = cpu_bus_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.ap.connect(scb.ap_export);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
