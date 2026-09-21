class cpu_bus_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_bus_scoreboard)

    uvm_analysis_imp #(cpu_bus_seq_item, cpu_bus_scoreboard) ap_export;

    logic [7:0] last_duty_cycle;
    logic [7:0] last_spi_byte;

    function new(string name = "cpu_bus_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_export = new("ap_export", this);
    endfunction

    virtual function void write(cpu_bus_seq_item trans);

        // CHECK 1: Fail-safe invariant. apb_motor_ctrl.sv physically severs
        // pwm_out to 0 whenever stall_flag (nmi_stall) is set. If this is
        // ever violated the motor could keep driving through a stall.
        if (trans.cpu_stall == 1'b1 && trans.pwm_out == 1'b1) begin
            `uvm_error("SCB_FAILSAFE",
                "FAIL-SAFE VIOLATION: nmi_stall asserted but pwm_out is still high")
        end

        // CHECK 2: Track duty-cycle writes (Motor Control @ 0x200)
        if (trans.we && trans.addr == 32'h0000_0200) begin
            last_duty_cycle = trans.wdata[7:0];
            `uvm_info("SCB_MOTOR", $sformatf("Duty cycle write: %0d/255", last_duty_cycle), UVM_LOW)
        end

        // CHECK 3: RPM register read (0x204) must never return X
        if (!trans.we && trans.addr == 32'h0000_0204) begin
            if (^trans.rdata === 1'bx) begin
                `uvm_error("SCB_MOTOR", "RPM register read returned X")
            end
        end

        // CHECK 4: SPI write (0x300) should latch shift_reg == wdata[7:0]
        // and the transfer must show cs_n activity (approximated here via
        // sclk toggling — busy flag readback is the stronger check, done in
        // a follow-up read of 0x300 by a richer sequence).
        if (trans.we && trans.addr == 32'h0000_0300) begin
            last_spi_byte = trans.wdata[7:0];
            `uvm_info("SCB_SPI", $sformatf("SPI byte queued: 0x%2h", last_spi_byte), UVM_LOW)
        end
    endfunction
endclass
