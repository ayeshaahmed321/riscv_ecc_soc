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

    // Generate Reset
    initial begin
        reset = 1;
        #10 reset = 0;
    end

    // The physical interface (UVM Driver acts as the Bus Master)
    ecc_mem_if vif(clk, reset);

    // Internal Subsystem Wires
    logic [31:0] sram_addr, sram_wdata, ecc_clean_data;
    logic        sram_we;
    logic [38:0] sram_in, sram_out, injected_data, fault_mask;
    logic        single_err, double_err;

    // Route error flags to the interface so the UVM Monitor can see them
    assign vif.single_err = single_err;
    assign vif.double_err = double_err;

    // 1. AXI SRAM Subsystem
    axi_ecc_memory axi_sram (
        .aclk(clk), .aresetn(~reset), 
        .awaddr(vif.awaddr), .awvalid(vif.awvalid), .awready(vif.awready),
        .wdata(vif.wdata), .wvalid(vif.wvalid), .wready(vif.wready),
        .bresp(vif.bresp), .bvalid(vif.bvalid), .bready(vif.bready),
        .araddr(vif.araddr), .arvalid(vif.arvalid), .arready(vif.arready),
        .rdata(vif.rdata), .rresp(vif.rresp), .rvalid(vif.rvalid), .rready(vif.rready),
        .mem_addr(sram_addr), .mem_wdata(sram_wdata), .mem_we(sram_we), .ecc_rdata(ecc_clean_data)
    );

    // 2. APB Register Subsystem
    apb_ecc_registers apb_regs (
        .pclk(clk), .presetn(~reset),
        .psel(vif.psel), .penable(vif.penable), .pwrite(vif.pwrite),
        .paddr(vif.paddr), .pwdata(vif.pwdata), .prdata(vif.prdata), .pready(vif.pready), 
        .pslverr(), // Unused in this simplified APB implementation
        .fault_mask(fault_mask), .single_err(single_err), .double_err(double_err)
    );

    // 3. The Physical Hardware Core
    ecc_encoder enc (
        .data_in(sram_wdata), 
        .ecc_out(sram_in)
    );
    
    sram_memory #(.DEPTH(64), .ADDR_WIDTH(6)) sram (
        .clk(clk), 
        .we(sram_we), 
        .addr(sram_addr[7:2]), 
        .data_in(sram_in), 
        .data_out(sram_out)
    );
    
    fault_injector gremlin (
        .data_in(sram_out), 
        .fault_mask(fault_mask), 
        .data_out(injected_data)
    );
    
    ecc_decoder dec (
        .ecc_in(injected_data), 
        .data_out(ecc_clean_data), 
        .single_error(single_err), 
        .double_error(double_err)
    );

    initial begin
        // Pass the physical interface to the UVM configuration database
        uvm_config_db#(virtual ecc_mem_if)::set(null, "*", "vif", vif);
        
        // Launch the UVM Test
        run_test("ecc_mem_test");
    end
endmodule