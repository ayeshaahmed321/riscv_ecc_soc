class ecc_mem_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ecc_mem_scoreboard)

    uvm_analysis_imp #(ecc_mem_seq_item, ecc_mem_scoreboard) ap_export;

    logic [31:0] shadow_mem [int];
    int unsigned checked_reads;
    int unsigned checked_single;
    int unsigned checked_double;

    function new(string name = "ecc_mem_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_export = new("ap_export", this);
        checked_reads = 0;
        checked_single = 0;
        checked_double = 0;
    endfunction

    virtual function void write(ecc_mem_seq_item trans);
        int bits_flipped;
        logic [31:0] expected_data;

        if (trans.addr >= 32'h0000_0100)
            return;

        if (trans.we) begin
            shadow_mem[trans.addr] = trans.wdata;
            return;
        end

        checked_reads++;
        bits_flipped = $countones(trans.fault_mask);
        expected_data = shadow_mem.exists(trans.addr) ? shadow_mem[trans.addr] : 32'h0;

        case (bits_flipped)
            0: begin
                if (trans.single_err !== 1'b0 || trans.double_err !== 1'b0)
                    `uvm_error("SCB_ECC", "Clean read reported an ECC error")
                if (trans.rdata !== expected_data)
                    `uvm_error("SCB_ECC", $sformatf(
                        "Clean read mismatch: expected=0x%08h got=0x%08h",
                        expected_data, trans.rdata))
            end

            1: begin
                checked_single++;
                if (trans.single_err !== 1'b1)
                    `uvm_error("SCB_ECC", "Single-bit error was not reported")
                if (trans.double_err !== 1'b0)
                    `uvm_error("SCB_ECC", "Single-bit error incorrectly reported as double")
                if (trans.rdata !== expected_data)
                    `uvm_error("SCB_ECC", $sformatf(
                        "Single-bit correction failed: expected=0x%08h got=0x%08h",
                        expected_data, trans.rdata))
            end

            2: begin
                checked_double++;
                if (trans.double_err !== 1'b1)
                    `uvm_error("SCB_ECC", "Double-bit error was not detected")
            end

            default: begin
                `uvm_info("SCB_ECC",
                    $sformatf("Skipping data-value comparison for %0d-bit injected fault",
                              bits_flipped), UVM_HIGH)
            end
        endcase
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB_ECC", $sformatf(
            "ECC checked reads=%0d, single-bit=%0d, double-bit=%0d",
            checked_reads, checked_single, checked_double), UVM_LOW)

        if (checked_reads == 0)
            `uvm_error("SCB_ECC", "Scoreboard checked zero memory reads")
        if (checked_single == 0)
            `uvm_error("SCB_ECC", "Scoreboard checked zero single-bit cases")
        if (checked_double == 0)
            `uvm_error("SCB_ECC", "Scoreboard checked zero double-bit cases")
    endfunction
endclass
