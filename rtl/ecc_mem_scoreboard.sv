class ecc_mem_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ecc_mem_scoreboard)

    uvm_analysis_imp #(ecc_mem_seq_item, ecc_mem_scoreboard) ap_export;

    logic [31:0] shadow_mem [int];
    logic [7:0]  expected_pwm_threshold = 8'h80; 
    logic [7:0]  last_spi_transmitted   = 8'h00;

    function new(string name = "ecc_mem_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_export = new("ap_export", this);
    endfunction

    virtual function void write(ecc_mem_seq_item trans);
        
        // CHECK 1: HIGH-SPEED ECC SRAM MEMORY SPACE
        if (trans.addr < 32'h0000_0100) begin
            if (trans.we) begin
                shadow_mem[trans.addr] = trans.wdata;
                `uvm_info("SCB", $sformatf("PC [0x%8h]: Shadow Written. Addr=0x%8h, Data=0x%8h", trans.pc, trans.addr, trans.wdata), UVM_HIGH)
            end else begin
                int bits_flipped = $countones(trans.fault_mask);
                logic [31:0] expected_data = shadow_mem.exists(trans.addr) ? shadow_mem[trans.addr] : 32'h0;

                if (bits_flipped == 0) begin
                    if (trans.rdata !== expected_data) begin
                        `uvm_error("SCB_ECC", \$sformatf("MISMATCH! Expected=0x%8h, Got=0x%8h", expected_data, trans.rdata))
                    end
                end
                else if (bits_flipped == 1) begin
                    if (trans.single_err !== 1'b1) begin
                        `uvm_error("SCB_ECC", "ALARM MISSED! single_err remained LOW")
                    end
                    if (trans.rdata !== expected_data) begin
                        `uvm_error("SCB_ECC", "CORRECTION FAILED! Data not repaired.")
                    end
                end 
                else if (bits_flipped == 2) begin
                    if (trans.double_err !== 1'b1) begin
                        `uvm_error("SCB_ECC", "CRITICAL FAIL! double_err remained LOW")
                    end
                end
            end
        end

        // CHECK 2: APB PERIPHERALS SYSTEM
        else begin
            if (trans.we) begin
                case (trans.addr)
                    32'h0000_0108: begin
                        last_spi_transmitted = trans.wdata[7:0];
                        `uvm_info("SCB_SPI", \$sformatf("PC [0x%8h]: SPI Out: 0x%2h", trans.pc, last_spi_transmitted), UVM_LOW)
                    end
                    32'h0000_010C: begin
                        expected_pwm_threshold = trans.wdata[7:0];
                        `uvm_info("SCB_PWM", $sformatf("PC [0x%8h]: PWM Duty Cycle = %0d/255", trans.pc, expected_pwm_threshold), UVM_LOW)
                    end
                endcase
            end
        end

        // CHECK 3: FAIL-SAFE WATCHDOG CHECK
        if (trans.wdog_reset_out == 1'b1) begin
            `uvm_info("SCB_FAILSAFE", \$sformatf("ALERT: Watchdog Reset detected at PC [0x%8h]", trans.pc), UVM_LOW)
        end
    endfunction
endclass
