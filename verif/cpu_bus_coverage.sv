class cpu_bus_coverage extends uvm_subscriber #(cpu_bus_seq_item);
    `uvm_component_utils(cpu_bus_coverage)

    cpu_bus_seq_item tr;

    covergroup cg;
        option.per_instance = 1;

        cp_we: coverpoint tr.we {
            bins write = {1'b1};
            bins read  = {1'b0};
        }

        cp_addr: coverpoint tr.addr {
            bins motor_duty    = {32'h0000_0200};
            bins motor_rpm     = {32'h0000_0204};
            bins motor_stall   = {32'h0000_0208};
            bins profile_steps = {[32'h0000_0210 : 32'h0000_022C]};
            bins profile_ctrl  = {32'h0000_0230};
            bins profile_index = {32'h0000_0234};
            bins spi_data      = {32'h0000_0300};
            bins spi_status    = {32'h0000_0304};
        }

        cp_pwm: coverpoint tr.pwm_out {
            bins low  = {1'b0};
            bins high = {1'b1};
        }

        cp_failsafe: coverpoint tr.cpu_stall { // fail-safe / nmi_stall flag
            bins stalled     = {1'b1};
            bins not_stalled = {1'b0};
        }

        cp_spi_activity: coverpoint tr.spi_mosi {
            bins zero = {1'b0};
            bins one  = {1'b1};
        }

        // Did we ever see the fail-safe trip WHILE pwm_out correctly stayed low?
        x_failsafe_holds: cross cp_failsafe, cp_pwm {
            ignore_bins bad_combo_not_scored_here =
                binsof(cp_failsafe.stalled) && binsof(cp_pwm.high);
                // (this exact combo is a bug, not a coverage goal —
                //  it is flagged separately by cpu_bus_scoreboard as an error)
        }

        // Only the combos the sequence actually drives are counted; the
        // others (e.g. reading a write-only duty register) can never
        // legitimately happen given this register map, so they're excluded
        // rather than left as permanently-uncoverable holes.
        x_addr_vs_we: cross cp_addr, cp_we {
            ignore_bins duty_read_never_happens    = binsof(cp_addr.motor_duty) && binsof(cp_we.read);
            ignore_bins rpm_write_never_happens    = binsof(cp_addr.motor_rpm)  && binsof(cp_we.write);
            ignore_bins spi_read_never_happens     = binsof(cp_addr.spi_data)   && binsof(cp_we.read);
            ignore_bins status_write_never_happens = binsof(cp_addr.spi_status) && binsof(cp_we.write);
            ignore_bins profile_steps_read_never_happens = binsof(cp_addr.profile_steps) && binsof(cp_we.read);
            ignore_bins profile_index_write_never_happens = binsof(cp_addr.profile_index) && binsof(cp_we.write);
        }
    endgroup

    function new(string name = "cpu_bus_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg = new();
    endfunction

    virtual function void write(cpu_bus_seq_item t);
        tr = t;
        cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("cpu_bus functional coverage = %0.2f%%", cg.get_coverage()), UVM_LOW)
    endfunction
endclass
