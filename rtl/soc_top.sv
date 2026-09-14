module soc_top (
    input logic clk,
    input logic reset
);
    // Core signals
    logic [31:0] pc, instr;
    logic [31:0] data_addr, core_wdata, core_rdata;
    logic        core_we;

    // Memory system signals
    logic [38:0] sram_in, sram_out, injected_data;
    logic [31:0] ecc_data_out;
    logic        single_err, double_err;

    // Memory-mapped registers
    logic [38:0] fault_mask_reg;
    logic [31:0] status_reg;

    // Address Decoding Logic
    logic is_dmem, is_fault_reg, is_status_reg;
    assign is_dmem       = (data_addr < 32'h0100);
    assign is_fault_reg  = (data_addr == 32'h0100);
    assign is_status_reg = (data_addr == 32'h0104);

    // Read MUX: What does the core see when it executes 'LW'?
    assign core_rdata = is_dmem       ? ecc_data_out :
                        is_status_reg ? {30'd0, double_err, single_err} : 
                        32'd0;

    // Write Logic for Peripheral Registers
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fault_mask_reg <= 39'd0;
        end else if (core_we && is_fault_reg) begin
            // We only expose the lower 32-bits to the 32-bit core
            fault_mask_reg <= {7'd0, core_wdata}; 
        end
    end

    // --- INSTANTIATE ALL MODULES ---

    imem instruction_mem (
        .addr(pc),
        .instr(instr)
    );

    rv32i_core processor (
        .clk(clk),
        .reset(reset),
        .instr(instr),
        .dmem_rdata(core_rdata),
        .pc_out(pc),
        .alu_result(data_addr),
        .dmem_wdata(core_wdata),
        .dmem_we(core_we)
    );

    ecc_encoder encoder (
        .data_in(core_wdata),
        .ecc_out(sram_in)
    );

    sram_memory #(.DEPTH(64), .ADDR_WIDTH(6)) dmem (
        .clk(clk),
        .we(core_we & is_dmem), // Only write if address is in SRAM range
        .addr(data_addr[7:2]),  // Word aligned
        .data_in(sram_in),
        .data_out(sram_out)
    );

    fault_injector gremlin (
        .data_in(sram_out),
        .fault_mask(fault_mask_reg),
        .data_out(injected_data)
    );

    ecc_decoder decoder (
        .ecc_in(injected_data),
        .data_out(ecc_data_out),
        .single_error(single_err),
        .double_error(double_err)
    );

endmodule