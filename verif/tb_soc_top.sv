// tb_soc_top.sv — Directed, self-checking SystemVerilog testbench (NOT UVM).
// Runs the real RV32I core against the hand-assembled program in imem.sv and
// white-box-snoops soc_top's internal signals (hierarchical reference) to
// check reset, clean memory instructions, single-bit correction, and
// double-bit detection — no external agent/driver framework needed.
`timescale 1ns/1ps

module tb_soc_top;
    logic clk;
    logic reset;

    logic pwm_out, tacho_in;
    logic sclk, mosi, miso, cs_n;

    int errors = 0;

    // ---------------- Clock / Reset ----------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset    = 1;
        tacho_in = 0;
        miso     = 1;
        repeat (2) @(posedge clk);
        reset = 0;
    end

    // ---------------- DUT ----------------
    soc_top dut (
        .clk(clk),
        .reset(reset),
        .pwm_out(pwm_out),
        .tacho_in(tacho_in),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // ---------------- Helpers ----------------
    task automatic check(string name, logic [31:0] got, logic [31:0] expected);
        if (got !== expected) begin
            $display("[FAIL] %-40s got=0x%08h expected=0x%08h @ %0t", name, got, expected, $time);
            errors++;
        end else begin
            $display("[PASS] %-40s value=0x%08h @ %0t", name, got, $time);
        end
    endtask

    task automatic check_bit(string name, logic got, logic expected);
        if (got !== expected) begin
            $display("[FAIL] %-40s got=%0b expected=%0b @ %0t", name, got, expected, $time);
            errors++;
        end else begin
            $display("[PASS] %-40s value=%0b @ %0t", name, got, $time);
        end
    endtask

    // Wait until PC reaches (i.e. has fetched/moved past) a given fetch
    // address; by then the instruction that lived there has already
    // completed its writeback (writeback happens the same cycle stall
    // clears, before PC advances to the next fetch).
    task automatic wait_until_pc(logic [31:0] target);
        while (dut.pc !== target) @(posedge clk);
        @(posedge clk); // settle margin
    endtask

    // ---------------- Directed test sequence ----------------
    initial begin
        $display("==================================================");
        $display(" Directed self-checking testbench: tb_soc_top");
        $display("==================================================");

        // --- TEST 1: Reset ---
        // While reset is held, PC and the register file must be forced to 0.
        @(posedge clk);
        check("RESET: pc == 0", dut.pc, 32'h0);
        check("RESET: regfile[x5] == 0", dut.processor.regfile[5], 32'h0);
        wait (reset == 0);
        $display("-- reset released --");

        // --- TEST 2: Memory instructions + clean ECC read ---
        // Program (imem.sv) writes 0x123 to SRAM addr 0 with fault_mask=0,
        // then reads it back into x7. Expect a clean decode: data matches,
        // no single/double error reported.
        wait_until_pc(32'h28); // past the LW x7,0(x5) at 0x24
        check("MEM: x7 == 0x123 (clean read)", dut.processor.regfile[7], 32'h123);
        check_bit("ECC: single_err == 0 (clean)", dut.single_err, 1'b0);
        check_bit("ECC: double_err == 0 (clean)", dut.double_err, 1'b0);

        // --- TEST 3: Single-bit fault -> corrected ---
        // Program sets fault_mask=1 then re-reads the same address into x10.
        // SECDED must silently correct it: data still 0x123, single_err=1.
        wait_until_pc(32'h38); // past the LW x10,0(x5) at 0x34
        check("ECC: x10 == 0x123 (single-bit corrected)", dut.processor.regfile[10], 32'h123);
        check_bit("ECC: single_err == 1 (single fault)", dut.single_err, 1'b1);
        check_bit("ECC: double_err == 0 (single fault)", dut.double_err, 1'b0);

        // --- TEST 4: Double-bit fault -> detected ---
        // Program sets fault_mask=3 (2 bits) then re-reads into x12.
        // Data is uncorrectable by design; only double_err is checked.
        wait_until_pc(32'h44); // past the LW x12,0(x5) at 0x40
        check_bit("ECC: single_err == 0 (double fault)", dut.single_err, 1'b0);
        check_bit("ECC: double_err == 1 (double fault)", dut.double_err, 1'b1);

        // --- TEST 5: Injected-fault cleanup (error reporting recovers) ---
        // Program clears fault_mask back to 0 at the end.
        wait_until_pc(32'h4C);
        check("CLEANUP: fault_mask == 0", dut.fault_mask, 39'h0);

        // --- TEST 6: New-ISA smoke test — R-type ALU, branch, jump ---
        wait_until_pc(32'h60);
        check("ISA: x14 == ADD(x1,x2) == 0x27F", dut.processor.regfile[14], 32'h27F);
        check("ISA: x15 == 5 (control value)",   dut.processor.regfile[15], 32'h5);
        check("ISA: x16 == 0 (BEQ correctly skipped it)", dut.processor.regfile[16], 32'h0);
        check("ISA: x17 == 111 (branch landed correctly)", dut.processor.regfile[17], 32'h6F);

        wait_until_pc(32'h6C);
        check("ISA: x18 == 0x64 (JAL link = pc+4)", dut.processor.regfile[18], 32'h64);
        check("ISA: x19 == 0 (JAL correctly skipped it)", dut.processor.regfile[19], 32'h0);
        check("ISA: x20 == 222 (jump landed correctly)", dut.processor.regfile[20], 32'hDE);

        // ---------------- Summary ----------------
        $display("==================================================");
        if (errors == 0) begin
            $display(" ALL TESTS PASSED");
        end else begin
            $display(" %0d TEST(S) FAILED", errors);
        end
        $display("==================================================");

        if (errors != 0) $fatal(1, "Directed self-checking testbench failed");
        $finish;
    end

    // Safety timeout in case the DUT hangs (e.g. interconnect never
    // deasserts stall) so the sim doesn't run forever.
    initial begin
        #20000;
        $display("[FAIL] TIMEOUT: simulation did not finish in time");
        $fatal(1, "Testbench timeout");
    end
endmodule
