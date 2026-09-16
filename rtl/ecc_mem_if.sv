interface ecc_mem_if(input logic clk, input logic reset);
    // AXI4-Lite Memory Channels
    logic [31:0] awaddr; logic awvalid; logic awready;
    logic [31:0] wdata;  logic wvalid;  logic wready;
    logic [1:0]  bresp;  logic bvalid;  logic bready;
    logic [31:0] araddr; logic arvalid; logic arready;
    logic [31:0] rdata;  logic [1:0] rresp; logic rvalid; logic rready;

    // APB Register Channels
    logic        psel, penable, pwrite, pready;
    logic [31:0] paddr, pwdata, prdata;

    // Direct hardware observation for the Monitor
    logic single_err, double_err;
endinterface