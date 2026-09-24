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
    logic [7:0] spi_captured_tx;
    logic [7:0] spi_captured_rx;
    logic       spi_capture_done;
    logic [3:0] spi_capture_bits;

    // SPI capture is event-based. The previous version used a task with a
    // while loop and could miss the transfer in the UVM sampling window.
    initial begin
        spi_captured_tx = 8'h00;
        spi_captured_rx = 8'h00;
        spi_capture_done = 1'b0;
        spi_capture_bits = 4'd0;
    end

    always @(negedge cs_n) begin
        spi_captured_tx = 8'h00;
        spi_captured_rx = 8'h00;
        spi_capture_done = 1'b0;
        spi_capture_bits = 4'd0;
    end

    always @(posedge sclk) begin
        if (!cs_n && spi_capture_bits < 8) begin
            spi_captured_tx = {spi_captured_tx[6:0], mosi};
            spi_captured_rx = {spi_captured_rx[6:0], miso};
            spi_capture_bits = spi_capture_bits + 1'b1;
            if (spi_capture_bits == 8)
                spi_capture_done = 1'b1;
        end
    end
endinterface