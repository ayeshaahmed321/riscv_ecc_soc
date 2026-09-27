import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_sequence extends uvm_sequence #(cpu_bus_seq_item);
    `uvm_object_utils(cpu_bus_sequence)

    function new(string name = "cpu_bus_sequence");
        super.new(name);
    endfunction

    task body();
        cpu_bus_seq_item req;
        logic [7:0] spi_byte = 8'hA5;

        // 1. Manual PWM duty. The testbench supplies tachometer pulses so
        // the motor can run without tripping the stall detector immediately.
        req = cpu_bus_seq_item::type_id::create("duty_write");
        start_item(req);
        void'(req.randomize() with {
            addr == 32'h0000_0200;
            we == 1'b1;
            wdata[7:0] == 8'd64;
        });
        finish_item(req);

        // 2. Give the monitor a complete 256-cycle PWM window.
        #2600ns;

        // 3. RPM must be non-zero while tachometer pulses are active.
        req = cpu_bus_seq_item::type_id::create("rpm_read");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0204; we == 1'b0; });
        finish_item(req);

        // 4. Read back duty register. Scoreboard also uses this transaction
        // to validate the captured 256-cycle PWM waveform.
        req = cpu_bus_seq_item::type_id::create("duty_read");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0200; we == 1'b0; });
        finish_item(req);

        // 5. SPI write.
        req = cpu_bus_seq_item::type_id::create("spi_write");
        start_item(req);
        void'(req.randomize() with {
            addr == 32'h0000_0300;
            we == 1'b1;
            wdata[7:0] == spi_byte;
        });
        finish_item(req);

        // SPI needs 8 bits x 16 peripheral clocks in this RTL.
        #1500ns;

        // 6. SPI RX/status read. MISO is held at 1 in the UVM top, so RX=FF.
        req = cpu_bus_seq_item::type_id::create("spi_read");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0304; we == 1'b0; });
        finish_item(req);

        // 7. Load an 8-step speed profile.
        for (int i = 0; i < 8; i++) begin
            req = cpu_bus_seq_item::type_id::create($sformatf("profile_%0d", i));
            start_item(req);
            void'(req.randomize() with {
                addr == 32'h0000_0210 + (i * 4);
                we == 1'b1;
                wdata == (10 * (i + 1));
            });
            finish_item(req);
        end

        // 8. Start profile.
        req = cpu_bus_seq_item::type_id::create("profile_start");
        start_item(req);
        void'(req.randomize() with {
            addr == 32'h0000_0230;
            we == 1'b1;
            wdata[0] == 1'b1;
        });
        finish_item(req);

        // 9. Profile takes approximately 8 x 10 clocks in this test top.
        #900ns;

        req = cpu_bus_seq_item::type_id::create("profile_status");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0230; we == 1'b0; });
        finish_item(req);

        req = cpu_bus_seq_item::type_id::create("profile_index");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0234; we == 1'b0; });
        finish_item(req);

        // 10. Tachometer drive stops in tb_uvm_system_top after the healthy
        // interval. Wait for the shortened stall window to expire.
        #700ns;

        req = cpu_bus_seq_item::type_id::create("stall_read");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0208; we == 1'b0; });
        finish_item(req);

        // 11. W1C clear.
        req = cpu_bus_seq_item::type_id::create("stall_clear");
        start_item(req);
        void'(req.randomize() with {
            addr == 32'h0000_0208;
            we == 1'b1;
            wdata[0] == 1'b1;
        });
        finish_item(req);

        // 12. Verify recovery.
        req = cpu_bus_seq_item::type_id::create("stall_read_clear");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0208; we == 1'b0; });
        finish_item(req);
    endtask
endclass
