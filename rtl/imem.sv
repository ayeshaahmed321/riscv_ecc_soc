module imem (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    always_comb begin
        case (addr)
            // --- 1. Motor Control Test ---
            // ADDI x1, x0, 0x200 (Load Motor Register Address)
            32'h00: instr = 32'h20000093; 
            // ADDI x2, x0, 0x7F  (Load Duty Cycle: 127, ~50% speed)
            32'h04: instr = 32'h07F00113; 
            // SW x2, 0(x1)       (Write 127 to 0x200)
            32'h08: instr = 32'h0020A023; 

            // --- 2. SPI Master Test ---
            // ADDI x3, x0, 0x300 (Load SPI Register Address)
            32'h0C: instr = 32'h30000193; 
            // ADDI x4, x0, 0xAA  (Load SPI Data: 0xAA / 10101010)
            32'h10: instr = 32'h0AA00213; 
            // SW x4, 0(x3)       (Write 0xAA to 0x300)
            32'h14: instr = 32'h0041A023; 

            // --- 3. Infinite Loop to keep CPU active ---
            // ADDI x0, x0, 0 (NOP)
            default: instr = 32'h00000013; 
        endcase
    end
endmodule