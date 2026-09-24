module tb_uvm_system_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import cpu_bus_pkg::*;

    logic clk, reset;
    initial begin clk = 0; forever #5 clk = ~clk; end
    initial begin reset = 1; #10 reset = 0; end

    cpu_bus_if vif(clk, reset);

    logic pwm_out, sclk, mosi, cs_n, nmi_stall_w;
    logic tacho_drive;

    logic [31:0] prdata_motor, prdata_spi;
    logic pready_motor, pready_spi, psel_motor, psel_spi, penable, pwrite;
    logic [31:0] paddr, pwdata;

    // Tachometer model:
    // healthy pulses are supplied long enough to validate RPM and PWM.
    // Pulses then stop, allowing the shortened stall detector to trigger.
    initial begin
        tacho_drive = 1'b0;
        wait (reset == 1'b0);
        repeat (90) begin
            #40 tacho_drive = ~tacho_drive;
        end
        tacho_drive = 1'b0;
    end

    assign vif.pwm_out  = pwm_out;
    assign vif.tacho_in = tacho_drive;
    assign vif.nmi_stall = nmi_stall_w;
    assign vif.sclk     = sclk;
    assign vif.mosi     = mosi;
    assign vif.miso     = 1'b1;
    assign vif.cs_n     = cs_n;

    amba_interconnect bus_matrix (
        .clk(clk), .reset(reset),
        .mem_req(vif.req), .cpu_addr(vif.addr), .cpu_wdata(vif.wdata),
        .cpu_we(vif.we), .cpu_rdata(vif.rdata), .cpu_stall(vif.stall),

        .awaddr(), .awvalid(), .awready(1'b0),
        .wdata(), .wvalid(), .wready(1'b0),
        .bresp(2'b00), .bvalid(1'b0), .bready(),
        .araddr(), .arvalid(), .arready(1'b0),
        .rdata(32'h0), .rresp(2'b00), .rvalid(1'b0), .rready(),
        .psel_ecc(), .prdata_ecc(32'h0), .pready_ecc(1'b1),

        .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),

        .psel_motor(psel_motor), .prdata_motor(prdata_motor), .pready_motor(pready_motor),
        .psel_spi(psel_spi), .prdata_spi(prdata_spi), .pready_spi(pready_spi)
    );

    apb_motor_ctrl #(.STALL_WINDOW(20'd50), .PROFILE_STEP_TIME(20'd10)) motor (
        .pclk(clk), .presetn(~reset),
        .psel(psel_motor), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata_motor), .pready(pready_motor),
        .pwm_out(pwm_out), .tacho_in(tacho_drive), .nmi_stall(nmi_stall_w)
    );

    apb_spi_master spi (
        .pclk(clk), .presetn(~reset),
        .psel(psel_spi), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata_spi), .pready(pready_spi),
        .sclk(sclk), .mosi(mosi), .miso(1'b1), .cs_n(cs_n)
    );

    initial begin
        uvm_config_db#(virtual cpu_bus_if)::set(null, "*", "vif", vif);
        run_test("cpu_bus_test");
    end
endmodule
