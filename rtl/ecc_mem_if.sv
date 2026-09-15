interface ecc_mem_if (input logic clk, input logic reset);
    // Memory Bus Signals
    logic [31:0] data_addr;
    logic [31:0] core_wdata;
    logic        core_we;
    logic [31:0] core_rdata;
    
    // ECC Subsystem Flags
    logic [38:0] fault_mask; 
    logic        single_err;
    logic        double_err;
endinterface