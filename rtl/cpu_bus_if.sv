interface cpu_bus_if(input logic clk, input logic reset);
    logic        req;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        we;
    logic [31:0] rdata;
    logic        stall;

    // Peripheral monitor taps (added for UVM visibility into SPI/PWM/RPM/
    // stall/fail-safe behavior; driven from tb_uvm_system_top, read-only
    // from the monitor's point of view)
    logic        pwm_out;
    logic        tacho_in;
    logic        nmi_stall;   // motor fail-safe flag (stall_flag)
    logic        sclk;
    logic        mosi;
    logic        miso;
    logic        cs_n;
endinterface