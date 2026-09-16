module rv32i_core (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,       // ADDED: AMBA handshake pause signal
    input  logic [31:0] instr,
    input  logic [31:0] core_rdata,  // Renamed to match soc_top
    output logic [31:0] pc,          // Renamed to match soc_top
    output logic [31:0] data_addr,   // Renamed to match soc_top (was alu_result)
    output logic [31:0] core_wdata,  // Renamed to match soc_top
    output logic        core_we,     // Renamed to match soc_top
    output logic        mem_req      // ADDED: High for Loads/Stores
);
    logic [31:0] regfile [1:31];
    logic [6:0]  opcode;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] imm_i, imm_s;
    logic [31:0] rdata1, rdata2;

    // Fetch (MODIFIED: Added stall check)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'd0;
        else if (!stall) pc <= pc + 4; // Only move to next instruction if not stalled
    end

    // Decode (MODIFIED: Fixed 'opcdoe' typo)
    assign opcode  = instr[6:0];
    assign rd      = instr[11:7];
    assign rs1     = instr[19:15];
    assign rs2     = instr[24:20];
    assign mem_req = (opcode == 7'b0000011 || opcode == 7'b0100011);
    
    // Immediate extraction
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // Register File Read (Bypass x0)
    assign rdata1 = (rs1 != 0) ? regfile[rs1] : 32'd0;
    assign rdata2 = (rs2 != 0) ? regfile[rs2] : 32'd0;

    // Execute & Memory Control
    always_comb begin
        data_addr = 32'd0;
        core_we = 1'b0;
        core_wdata = rdata2;

        case(opcode)
            7'b0010011: data_addr = rdata1 + imm_i; // ADDI
            7'b0000011: data_addr = rdata1 + imm_i; // LW
            7'b0100011: begin                       // SW
                data_addr = rdata1 + imm_s;
                core_we = 1'b1;
            end
        endcase
    end

    // Writeback & Reset (MODIFIED: Added stall check)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 1; i < 32; i++) begin
                regfile[i] <= 32'd0;
            end
        end else if (!stall) begin // Only write to registers if the bus is ready
            if (rd != 0) begin
                if (opcode == 7'b0000011)      // LW
                    regfile[rd] <= core_rdata;
                else if (opcode == 7'b0010011) // ADDI
                    regfile[rd] <= data_addr;
            end
        end
    end
endmodule