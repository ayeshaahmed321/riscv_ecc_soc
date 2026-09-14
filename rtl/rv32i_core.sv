module rv32i_core (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instr,
    input  logic [31:0] dmem_rdata,
    output logic [31:0] pc_out,
    output logic [31:0] alu_result,
    output logic [31:0] dmem_wdata,
    output logic        dmem_we
);
    logic [31:0] pc;
    logic [31:0] regfile [1:31];
    logic [6:0]  opcode;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] imm_i, imm_s;
    logic [31:0] rdata1, rdata2;

    // Fetch
    always_ff @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'd0;
        else       pc <= pc + 4;
    end
    assign pc_out = pc;

    // Decode
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    
    // Immediate extraction
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // Register File Read (Bypass x0)
    assign rdata1 = (rs1 != 0) ? regfile[rs1] : 32'd0;
    assign rdata2 = (rs2 != 0) ? regfile[rs2] : 32'd0;

    // Execute & Memory Control
    always_comb begin
        alu_result = 32'd0;
        dmem_we = 1'b0;
        dmem_wdata = rdata2;

        case(opcode)
            7'b0010011: alu_result = rdata1 + imm_i; // ADDI
            7'b0000011: alu_result = rdata1 + imm_i; // LW
            7'b0100011: begin                        // SW
                alu_result = rdata1 + imm_s;
                dmem_we = 1'b1;
            end
        endcase
    end

    // Writeback & Reset (Single Driver Process)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 1; i < 32; i++) begin
                regfile[i] <= 32'd0;
            end
        end else if (rd != 0) begin
            if (opcode == 7'b0000011)      // LW
                regfile[rd] <= dmem_rdata;
            else if (opcode == 7'b0010011) // ADDI
                regfile[rd] <= alu_result;
        end
    end
endmodule