    initial begin
        // --- PHASE 1: TESTING A SINGLE (1-BIT) ERROR ---
        // 1. Load test data (A5A5A5A5) into register x1
        rom[0] = 32'hA5A5A093; 
        // 2. Set memory target address to 0 in register x2
        rom[1] = 32'h00000113; 
        // 3. Write data to SRAM slot 0 (ECC automatically encodes it)
        rom[2] = 32'h00112023;
        // 4. Load Fault Mask Register Address (0x100) into register x3
        rom[3] = 32'h10000193; 
        // 5. Create a 1-bit mask: The number 8 (binary 0000_1000 -> flips bit 3)
        rom[4] = 32'h00800213;
        // 6. Write mask to Fault Register (Gremlin is now armed for 1-bit flip)
        rom[5] = 32'h0041A023;
        // 7. Read SRAM slot 0. The Gremlin flips 1 bit. ECC Decoder fixes it!
        rom[6] = 32'h00012283; // x5 will hold perfectly clean data (A5A5A5A5)
        // 8. Read Status Dashboard (0x104) to verify single_err flag is UP
        rom[7] = 32'h0041A303; // x6 will read back 32'h00000001

        // --- PHASE 2: TESTING A DOUBLE (2-BIT) ERROR ---
        // 9. Create a 2-bit mask: The number 12 (binary 0000_1100 -> flips bit 2 AND bit 3)
        rom[8] = 32'h00C00213; // Changed immediate from 8 to 12!
        // 10. Write new 2-bit mask to Fault Register (Gremlin is armed for 2-bit flip)
        rom[9] = 32'h0041A023;
        // 11. Read SRAM slot 0 again. Gremlin flips 2 bits. ECC Decoder sounds alarm!
        rom[10] = 32'h00012383; // x7 holds corrupted data (Cannot fix!)
        // 12. Read Status Dashboard (0x104) to verify double_err flag is UP
        rom[11] = 32'h0041A403; // x8 will read back 32'h00000002
    end
