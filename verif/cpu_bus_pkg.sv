// cpu_bus_pkg.sv
package cpu_bus_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Order matters! Item must be included first so sequences/drivers understand it.
    `include "cpu_bus_seq_item.sv"
    `include "cpu_bus_sequence.sv"
    `include "cpu_bus_driver.sv"
    `include "cpu_bus_monitor.sv"
    `include "cpu_bus_scoreboard.sv"
    `include "cpu_bus_coverage.sv"
    `include "cpu_bus_env.sv"
    `include "cpu_bus_test.sv"
endpackage
