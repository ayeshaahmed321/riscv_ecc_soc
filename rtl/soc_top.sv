module soc_top (
    input  logic clk,
    input  logic reset,
    
    // Motor Control Physical I/O
    output logic pwm_out,
    input  logic tacho_in,
    
    // SPI Master Physical I/O
    output logic sclk,
    output logic mosi,
    input  logic miso,
    output logic cs_n
);
    // CPU Signals
    logic [31:0] instr, pc;
    logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
    logic        cpu_we, cpu_req, cpu_stall;

    // AMBA AXI-Lite Signals
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [1:0]  bresp, rresp;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic arvalid, arready, rvalid, rready;

    // AMBA APB Shared Signals
    logic [31:0] paddr, pwdata;
    logic penable, pwrite;

    // APB Slave 1 (ECC Registers)
    logic psel_ecc, pready_ecc;
    logic [31:0] prdata_ecc;

    // APB Slave 2 (Motor Control)
    logic psel_motor, pready_motor, nmi_stall;
    logic [31:0] prdata_motor;

    // APB Slave 3 (SPI Master)
    logic psel_spi, pready_spi;
    logic [31:0] prdata_spi;

    // Internal ECC Subsystem Wires
    logic [31:0] sram_addr, sram_wdata, ecc_clean_data;
    logic        sram_we;
    logic [38:0] sram_in, sram_out, injected_data, fault_mask;
    logic        single_err, double_err;

    // 1. Instruction Memory
    imem rom (.addr(pc), .instr(instr));

    // 2. The Processor
    rv32i_core processor (
        .clk(clk), .reset(reset), .stall(cpu_stall),
        .pc(pc), .instr(instr),
        .data_addr(cpu_addr), .core_wdata(cpu_wdata), .core_we(cpu_we),
        .core_rdata(cpu_rdata), .mem_req(cpu_req)
    );

    // 3. AMBA Interconnect Bridge
    amba_interconnect bus_matrix (
        .clk(clk), .reset(reset),
        .mem_req(cpu_req), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata), 
        .cpu_we(cpu_we), .cpu_rdata(cpu_rdata), .cpu_stall(cpu_stall),
        
        // AXI Ports
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        
        // APB Shared Ports
        .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata),
        
        // APB Slave 1: ECC
        .psel_ecc(psel_ecc), .prdata_ecc(prdata_ecc), .pready_ecc(pready_ecc),
        
        // APB Slave 2: Motor
        .psel_motor(psel_motor), .prdata_motor(prdata_motor), .pready_motor(pready_motor),
        
        // APB Slave 3: SPI
        .psel_spi(psel_spi), .prdata_spi(prdata_spi), .pready_spi(pready_spi)
    );

    // 4. AXI SRAM Subsystem
    axi_ecc_memory axi_sram (
        .aclk(clk), .aresetn(~reset), 
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .mem_addr(sram_addr), .mem_wdata(sram_wdata), .mem_we(sram_we), .ecc_rdata(ecc_clean_data)
    );

    // 5. APB Slave 1: ECC Registers
    apb_ecc_registers apb_regs (
        .pclk(clk), .presetn(~reset),
        .psel(psel_ecc), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata_ecc), .pready(pready_ecc), .pslverr(),
        .fault_mask(fault_mask), .single_err(single_err), .double_err(double_err)
    );

    // 6. APB Slave 2: Motor Control
    apb_motor_ctrl motor_ctrl (
        .pclk(clk), .presetn(~reset),
        .psel(psel_motor), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata_motor), .pready(pready_motor),
        .pwm_out(pwm_out), .tacho_in(tacho_in), .nmi_stall(nmi_stall)
    );

    // 7. APB Slave 3: SPI Master
    apb_spi_master spi_master (
        .pclk(clk), .presetn(~reset),
        .psel(psel_spi), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata_spi), .pready(pready_spi),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    // 8. The Physical Hardware
    ecc_encoder enc (.data_in(sram_wdata), .ecc_out(sram_in));
    
    sram_memory #(.DEPTH(64), .ADDR_WIDTH(6)) sram (
        .clk(clk), .we(sram_we), .addr(sram_addr[7:2]), .data_in(sram_in), .data_out(sram_out)
    );
    
    fault_injector gremlin (.data_in(sram_out), .fault_mask(fault_mask), .data_out(injected_data));
    
    ecc_decoder dec (
        .ecc_in(injected_data), .data_out(ecc_clean_data), 
        .single_error(single_err), .double_error(double_err)
    );
endmodule