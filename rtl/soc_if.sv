interface soc_if (input logic clk, input logic reset);
    // AXI4-Lite Memory Channels (Monitored by UVM)
    logic [31:0] awaddr; logic awvalid; logic awready;
    logic [31:0] wdata;  logic wvalid;  logic wready;
    logic [1:0]  bresp;  logic bvalid;  logic bready;
    logic [31:0] araddr; logic arvalid; logic arready;
    logic [31:0] rdata;  logic [1:0] rresp; logic rvalid; logic rready;

    // AMBA APB Register Channels (Monitored by UVM)
    logic        psel, penable, pwrite, pready;
    logic [31:0] paddr, pwdata, prdata;

    // CPU Internal Tracking Wires
    logic [31:0] pc;
    logic [31:0] instr;
    logic        cpu_stall;

    // ECC Functional Flags
    logic        single_err;
    logic        double_err;

    // Peripheral Protocol & Fail-Safe Tracking Wires
    logic        spi_mosi;
    logic        spi_miso;
    logic        spi_sclk;
    logic        pwm_out;
    logic        rpm_pulse_in;
    logic        wdog_reset_out;

    // Protocol-Safe Clocking Block for UVM Sampling
    clocking cb @(posedge clk);
        default input #1step output #1ns;
        
        // AXI Inputs
        input awaddr, awvalid, awready;
        input wdata, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arvalid, arready;
        input rdata, rresp, rvalid, rready;
        
        // APB Inputs
        input psel, penable, pwrite, pready;
        input paddr, pwdata, prdata;
        
        // CPU & ECC Inputs
        input pc, instr, cpu_stall;
        input single_err, double_err;

        // Peripheral Inputs
        input spi_mosi, spi_miso, spi_sclk;
        input pwm_out, rpm_pulse_in, wdog_reset_out;
    endclocking
endinterface
