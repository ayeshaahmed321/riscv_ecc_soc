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

            // --- 3. ECC-Protected Memory Test ---
            // ADDI x5, x0, 0x000  (SRAM base address)
            32'h18: instr = 32'h00000293;
            // ADDI x6, x0, 0x123  (test data)
            32'h1C: instr = 32'h12300313;
            // SW x6, 0(x5)        (clean write to SRAM addr 0)
            32'h20: instr = 32'h0062A023;
            // LW x7, 0(x5)        (clean read back -> x7 should == 0x123)
            32'h24: instr = 32'h0002A383;
            // ADDI x8, x0, 0x100  (fault_mask register address)
            32'h28: instr = 32'h10000413;
            // ADDI x9, x0, 1      (single-bit fault pattern)
            32'h2C: instr = 32'h00100493;
            // SW x9, 0(x8)        (inject single-bit fault)
            32'h30: instr = 32'h00942023;
            // LW x10, 0(x5)       (read w/ single fault -> corrected, x10 == 0x123, single_err=1)
            32'h34: instr = 32'h0002A503;
            // ADDI x11, x0, 3     (double-bit fault pattern)
            32'h38: instr = 32'h00300593;
            // SW x11, 0(x8)       (inject double-bit fault)
            32'h3C: instr = 32'h00B42023;
            // LW x12, 0(x5)       (read w/ double fault -> uncorrectable, double_err=1)
            32'h40: instr = 32'h0002A603;
            // ADDI x13, x0, 0     (clear pattern)
            32'h44: instr = 32'h00000693;
            // SW x13, 0(x8)       (clear fault_mask)
            32'h48: instr = 32'h00D42023;

            // --- 4. New-ISA smoke test (ALU R-type, branch, jump) ---
            // ADD x14, x1, x2     (R-type ALU: x14 = 0x200 + 0x7F = 0x27F)
            32'h4C: instr = 32'h00208733;
            // ADDI x15, x0, 5     (control value)
            32'h50: instr = 32'h00500793;
            // BEQ x0, x0, +8      (always taken -> must skip the next instr)
            32'h54: instr = 32'h00000463;
            // ADDI x16, x0, 999   (must be SKIPPED if branch works)
            32'h58: instr = 32'h3E700813;
            // ADDI x17, x0, 111   (branch lands here)
            32'h5C: instr = 32'h06F00893;
            // JAL x18, +8         (link = pc+4, jump -> must skip next instr)
            32'h60: instr = 32'h0080096F;
            // ADDI x19, x0, 888   (must be SKIPPED if jump works)
            32'h64: instr = 32'h37800993;
            // ADDI x20, x0, 222   (jump lands here)
            32'h68: instr = 32'h0DE00A13;

            // --- 5. Infinite Loop to keep CPU active ---
            // ADDI x0, x0, 0 (NOP)
            default: instr = 32'h00000013; 
        endcase
    end
endmodule