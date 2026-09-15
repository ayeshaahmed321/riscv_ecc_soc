import uvm_pkg::*;
`include "uvm_macros.svh"
import ecc_mem_pkg::*;

module tb_uvm_top;
    logic clk;
    logic reset;

    // Generate Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // The physical interface
    ecc_mem_if vif(clk, reset);

    // Intermediate wires for your hardware blocks
    logic [38:0] sram_in, sram_out, injected_data;

    // --- INSTANTIATE HARDWARE BLOCKS (Bypassing CPU) ---
    ecc_encoder enc (
        .data_in(vif.core_wdata),
        .ecc_out(sram_in)
    );

    sram_memory #(.DEPTH(64), .ADDR_WIDTH(6)) sram (
        .clk(clk),
        .we(vif.core_we),
        .addr(vif.data_addr[7:2]), // Word alignment
        .data_in(sram_in),
        .data_out(sram_out)
    );

    fault_injector gremlin (
        .data_in(sram_out),
        .fault_mask(vif.fault_mask),
        .data_out(injected_data)
    );

    ecc_decoder dec (
        .ecc_in(injected_data),
        .data_out(vif.core_rdata),
        .single_error(vif.single_err),
        .double_error(vif.double_err)
    );

    initial begin
        // Pass the physical interface to the UVM database
        uvm_config_db#(virtual ecc_mem_if)::set(null, "*", "vif", vif);
        
        // Launch the UVM Test
        run_test("ecc_mem_test");
    end
endmodule