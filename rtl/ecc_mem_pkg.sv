// ecc_mem_pkg.sv
package ecc_mem_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Order matters! Item must be included first so sequences/drivers understand it.
    `include "ecc_mem_seq_item.sv"
    `include "ecc_mem_sequence.sv"
    `include "ecc_mem_driver.sv"
    `include "ecc_mem_monitor.sv"
    `include "ecc_mem_scoreboard.sv"
    `include "ecc_mem_coverage.sv"
    `include "ecc_mem_env.sv"
    `include "ecc_mem_test.sv"
endpackage
