// rv32i_core.sv — single-cycle RV32I core.
//
// Implemented: LUI, AUIPC, JAL, JALR, all 6 branches (BEQ/BNE/BLT/BGE/
// BLTU/BGEU), all R-type ALU ops (ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND),
// all I-type ALU ops (ADDI/SLLI/SLTI/SLTIU/XORI/SRLI/SRAI/ORI/ANDI),
// LW/SW (word-only).
//
// NOT implemented: LB/LH/LBU/LHU/SB/SH (byte/halfword memory ops). The
// AXI/APB interconnect and SRAM in this design are word-only (no byte
// enables) — adding byte-granular access would require changes across
// amba_interconnect, axi_ecc_memory, and sram_memory that are out of scope
// here and would risk the already-verified (100% coverage) ECC memory
// path. A byte/halfword Load or Store instruction is decoded but treated
// as a no-op (mem_req stays low, no register writeback) rather than
// silently mis-executed as a word access.
//
// FENCE/ECALL/EBREAK/CSR instructions: not implemented (not required by
// the capstone spec — "advanced cores... not required").

module rv32i_core (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic [31:0] instr,
    input  logic [31:0] core_rdata,
    output logic [31:0] pc,
    output logic [31:0] data_addr,
    output logic [31:0] core_wdata,
    output logic        core_we,
    output logic        mem_req
);
    logic [31:0] regfile [1:31];

    // ---------------- Decode ----------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign rd     = instr[11:7];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];

    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_LOAD   = 7'b0000011;
    localparam logic [6:0] OP_STORE  = 7'b0100011;
    localparam logic [6:0] OP_ALUI   = 7'b0010011; // ALU-immediate
    localparam logic [6:0] OP_ALUR   = 7'b0110011; // ALU-register

    // ---------------- Immediates ----------------
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // ---------------- Register file read (x0 hardwired 0) ----------------
    logic [31:0] rdata1, rdata2;
    assign rdata1 = (rs1 != 0) ? regfile[rs1] : 32'd0;
    assign rdata2 = (rs2 != 0) ? regfile[rs2] : 32'd0;

    // ---------------- ALU ----------------
    logic [31:0] alu_op_b;   // second ALU operand: rdata2 (R-type) or imm_i (I-type)
    logic [31:0] alu_result;
    logic        is_alu_op;      // ALU-register or ALU-immediate
    logic        alt_op;         // SUB / SRA variant selector (funct7[5])

    assign is_alu_op = (opcode == OP_ALUR) || (opcode == OP_ALUI);
    assign alu_op_b  = (opcode == OP_ALUR) ? rdata2 : imm_i;
    // For R-type, funct7[5] (instr[30]) selects SUB/SRA. For I-type, only
    // shift ops (SRLI/SRAI, funct3=101) use instr[30] this way; ADDI etc.
    // must never treat instr[30] as an operation selector (it's just part
    // of the immediate).
    assign alt_op = (opcode == OP_ALUR) ? funct7[5]
                   : (funct3 == 3'b101) ? instr[30]
                   : 1'b0;

    always_comb begin
        case (funct3)
            3'b000:  alu_result = alt_op ? (rdata1 - alu_op_b) : (rdata1 + alu_op_b); // SUB/ADD/ADDI
            3'b001:  alu_result = rdata1 << alu_op_b[4:0];                            // SLL/SLLI
            3'b010:  alu_result = ($signed(rdata1) < $signed(alu_op_b)) ? 32'd1 : 32'd0; // SLT/SLTI
            3'b011:  alu_result = (rdata1 < alu_op_b) ? 32'd1 : 32'd0;                 // SLTU/SLTIU
            3'b100:  alu_result = rdata1 ^ alu_op_b;                                   // XOR/XORI
            3'b101:  alu_result = alt_op ? ($signed(rdata1) >>> alu_op_b[4:0])         // SRA/SRAI
                                          : (rdata1 >> alu_op_b[4:0]);                 // SRL/SRLI
            3'b110:  alu_result = rdata1 | alu_op_b;                                   // OR/ORI
            3'b111:  alu_result = rdata1 & alu_op_b;                                   // AND/ANDI
            default: alu_result = 32'd0;
        endcase
    end

    // ---------------- Branch condition ----------------
    logic branch_taken;
    always_comb begin
        case (funct3)
            3'b000:  branch_taken = (rdata1 == rdata2);                    // BEQ
            3'b001:  branch_taken = (rdata1 != rdata2);                    // BNE
            3'b100:  branch_taken = ($signed(rdata1) <  $signed(rdata2));  // BLT
            3'b101:  branch_taken = ($signed(rdata1) >= $signed(rdata2));  // BGE
            3'b110:  branch_taken = (rdata1 <  rdata2);                    // BLTU
            3'b111:  branch_taken = (rdata1 >= rdata2);                    // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // ---------------- Memory control ----------------
    // Word-only: a load/store only issues a bus transaction when funct3
    // selects the word-width encoding (3'b010); byte/half encodings are
    // decoded but treated as a no-op (see file header).
    logic is_load_word, is_store_word;
    assign is_load_word  = (opcode == OP_LOAD)  && (funct3 == 3'b010);
    assign is_store_word = (opcode == OP_STORE) && (funct3 == 3'b010);
    assign mem_req       = is_load_word || is_store_word;

    always_comb begin
        data_addr  = 32'd0;
        core_we    = 1'b0;
        core_wdata = rdata2;
        if (is_load_word)       data_addr = rdata1 + imm_i;
        else if (is_store_word) begin
            data_addr = rdata1 + imm_s;
            core_we   = 1'b1;
        end
    end

    // ---------------- Next PC ----------------
    logic [31:0] next_pc;
    always_comb begin
        next_pc = pc + 4;
        if (opcode == OP_JAL)
            next_pc = pc + imm_j;
        else if (opcode == OP_JALR)
            next_pc = (rdata1 + imm_i) & 32'hFFFF_FFFE;
        else if (opcode == OP_BRANCH && branch_taken)
            next_pc = pc + imm_b;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'd0;
        else if (!stall) pc <= next_pc;
    end

    // ---------------- Writeback & Reset ----------------
    logic [31:0] wb_value;
    logic        wb_enable;
    always_comb begin
        wb_value  = 32'd0;
        wb_enable = 1'b0;
        case (opcode)
            OP_LUI:    begin wb_value = imm_u;              wb_enable = 1'b1; end
            OP_AUIPC:  begin wb_value = pc + imm_u;         wb_enable = 1'b1; end
            OP_JAL:    begin wb_value = pc + 32'd4;         wb_enable = 1'b1; end
            OP_JALR:   begin wb_value = pc + 32'd4;         wb_enable = 1'b1; end
            OP_ALUR:   begin wb_value = alu_result;         wb_enable = 1'b1; end
            OP_ALUI:   begin wb_value = alu_result;         wb_enable = 1'b1; end
            OP_LOAD:   if (is_load_word) begin wb_value = core_rdata; wb_enable = 1'b1; end
            default: ; // BRANCH, STORE: no register writeback
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 1; i < 32; i++) begin
                regfile[i] <= 32'd0;
            end
        end else if (!stall) begin
            if (wb_enable && rd != 0)
                regfile[rd] <= wb_value;
        end
    end
endmodule
