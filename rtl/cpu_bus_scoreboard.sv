import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_bus_scoreboard)

    uvm_analysis_imp #(cpu_bus_seq_item, cpu_bus_scoreboard) ap_export;

    logic [7:0] last_duty_cycle;
    logic [7:0] last_spi_byte;
    int unsigned stall_read_count;
    bit pwm_checked;
    bit rpm_checked;
    bit spi_checked;
    bit profile_checked;
    bit stall_checked;

    function new(string name = "cpu_bus_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_export = new("ap_export", this);
        last_duty_cycle = 0;
        last_spi_byte = 0;
        stall_read_count = 0;
        pwm_checked = 0;
        rpm_checked = 0;
        spi_checked = 0;
        profile_checked = 0;
        stall_checked = 0;
    endfunction

    virtual function void write(cpu_bus_seq_item trans);

        // CHECK 1: fail-safe must force PWM low whenever stall is asserted.
        if (trans.cpu_stall && trans.pwm_out)
            `uvm_error("SCB_FAILSAFE", "nmi_stall asserted while pwm_out is high")

        // CHECK 2: manual PWM duty and measured 256-cycle waveform.
        if (trans.we && trans.addr == 32'h0000_0200) begin
            last_duty_cycle = trans.wdata[7:0];
            `uvm_info("SCB_PWM", $sformatf("Duty-cycle write = %0d/255", last_duty_cycle), UVM_LOW)
        end

        if (!trans.we && trans.addr == 32'h0000_0200 &&
            !pwm_checked && trans.pwm_samples >= 256) begin
            if ((trans.pwm_high_samples + 2 < last_duty_cycle) ||
                (trans.pwm_high_samples > last_duty_cycle + 2)) begin
                `uvm_error("SCB_PWM", $sformatf("PWM mismatch: duty=%0d, measured high=%0d/256", last_duty_cycle, trans.pwm_high_samples))
            end
            else begin
                `uvm_info("SCB_PWM", $sformatf("PWM verified: duty=%0d, measured high=%0d/256", last_duty_cycle, trans.pwm_high_samples), UVM_LOW)
            end
            pwm_checked = 1;
        end

        // CHECK 3: RPM must become non-zero when tachometer pulses are present.
        if (!trans.we && trans.addr == 32'h0000_0204) begin
            if (trans.rdata === 32'hx || trans.rdata === 32'hz || trans.rdata == 32'h0)
                `uvm_error("SCB_RPM", $sformatf("RPM check failed: rdata=0x%08h", trans.rdata))
            else
                `uvm_info("SCB_RPM", $sformatf("RPM check passed: count=%0d", trans.rdata), UVM_LOW)
            rpm_checked = 1;
        end

        // CHECK 4: SPI transmit byte must be observed on MOSI, and the MISO model must return 0xFF.
        if (trans.we && trans.addr == 32'h0000_0300) begin
            last_spi_byte = trans.wdata[7:0];
            `uvm_info("SCB_SPI", $sformatf("SPI expected TX byte = 0x%02h", last_spi_byte), UVM_LOW)
        end

        // Decouple the SPI physical check from the CPU's bus address
        if (trans.spi_transfer_done && !spi_checked) begin
            if (trans.spi_tx_observed !== last_spi_byte)
                `uvm_error("SCB_SPI", $sformatf("MOSI mismatch: expected=0x%02h observed=0x%02h", last_spi_byte, trans.spi_tx_observed))
            
            // Validate using the physical telemetry, not the CPU's bus read data
            if (trans.spi_rx_observed !== 8'hFF)
                `uvm_error("SCB_SPI", $sformatf("MISO/RX mismatch: expected=0xFF got=0x%02h", trans.spi_rx_observed))
            else
                `uvm_info("SCB_SPI", "SPI MOSI and RX data verified", UVM_LOW)
            
            spi_checked = 1;
        end

        // CHECK 5: Profile must finish and reach the final index.
        if (!trans.we && trans.addr == 32'h0000_0230) begin
            if (trans.rdata[0] !== 1'b0)
                `uvm_error("SCB_PROFILE", "Profile still running after wait")
            else
                profile_checked = 1;
        end

        if (!trans.we && trans.addr == 32'h0000_0234) begin
            if (trans.rdata[2:0] !== 3'd7)
                `uvm_error("SCB_PROFILE", $sformatf("Profile index=%0d, expected 7", trans.rdata[2:0]))
            else if (profile_checked)
                `uvm_info("SCB_PROFILE", "Profile loading/execution verified", UVM_LOW)
        end

        // CHECK 6: Explicitly verify stall status, including recovery.
        if (!trans.we && trans.addr == 32'h0000_0208) begin
            stall_read_count++;
            if (stall_read_count == 1) begin
                if (trans.rdata[0] !== 1'b1)
                    `uvm_error("SCB_STALL", "First stall-status read did not report stall")
                else begin
                    `uvm_info("SCB_STALL", "Stall detected and reported", UVM_LOW)
                    stall_checked = 1;
                end
            end
            else if (stall_read_count == 2) begin
                if (trans.rdata[0] !== 1'b0)
                    `uvm_error("SCB_STALL", "Stall flag did not clear after W1C")
                else
                    `uvm_info("SCB_STALL", "Stall flag cleared successfully", UVM_LOW)
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        if (!pwm_checked)
            `uvm_error("SCB_PWM", "PWM waveform was not checked")
        if (!rpm_checked)
            `uvm_error("SCB_RPM", "RPM register was not checked with non-zero result")
        if (!spi_checked)
            `uvm_error("SCB_SPI", "SPI transfer was not checked")
        if (!stall_checked)
            `uvm_error("SCB_STALL", "Stall status was not checked")
    endfunction
endclass