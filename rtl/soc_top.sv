module soc_top (
    input logic clk,
    input logic reset
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

    // AMBA APB Signals
    logic [31:0] paddr, pwdata, prdata;
    logic psel, penable, pwrite, pready, pslverr;

    // Internal Subsystem Wires
    logic [31:0] sram_addr, sram_wdata, ecc_clean_data;
    logic        sram_we;
    logic [38:0] sram_in, sram_out, injected_data, fault_mask;
    logic        single_err, double_err;

    // 1. Instruction Memory
    imem rom (.addr(pc), .instr(instr));

    // 2. The Processor (Now with stall logic)
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
        // APB Ports
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready)
    );

    // 4. AXI SRAM Subsystem
    axi_ecc_memory axi_sram (
        .aclk(clk), .aresetn(~reset), // Note: AXI uses active-low reset
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .mem_addr(sram_addr), .mem_wdata(sram_wdata), .mem_we(sram_we), .ecc_rdata(ecc_clean_data)
    );

    // 5. APB Register Subsystem
    apb_ecc_registers apb_regs (
        .pclk(clk), .presetn(~reset),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .fault_mask(fault_mask), .single_err(single_err), .double_err(double_err)
    );

    // 6. The Physical Hardware (Unchanged, wrapped by AMBA)
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