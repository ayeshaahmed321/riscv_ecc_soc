interface cpu_bus_if(input logic clk, input logic reset);
    logic        req;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        we;
    logic [31:0] rdata;
    logic        stall;
endinterface