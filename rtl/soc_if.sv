interface soc_if (input logic clk, input logic reset);
    // Signals we want UVM to monitor or drive
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] data_addr;
    logic [31:0] core_wdata;
    logic [31:0] core_rdata;
    logic        core_we;
    
    logic        single_err;
    logic        double_err;

    // A clocking block helps UVM sample signals safely without timing races
    clocking cb @(posedge clk);
        default input #1step output #1ns;
        input pc;
        input instr;
        input data_addr;
        input core_wdata;
        input core_rdata;
        input core_we;
        input single_err;
        input double_err;
    endclocking
endinterface