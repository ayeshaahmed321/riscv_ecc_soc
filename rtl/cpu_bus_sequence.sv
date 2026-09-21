import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_sequence extends uvm_sequence #(cpu_bus_seq_item);
    `uvm_object_utils(cpu_bus_sequence)

    function new(string name = "cpu_bus_sequence");
        super.new(name);
    endfunction

    task body();
        cpu_bus_seq_item req;

        // 1. Write Duty Cycle to Motor (0x200), forced > 10 so the stall
        //    condition in apb_motor_ctrl (duty_cycle > 10 && no tacho edges)
        //    is guaranteed reachable (tacho_in is tied low in this testbench).
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0200; we == 1'b1; wdata[7:0] > 10; });
        finish_item(req);

        // 2. Read RPM Count (0x204)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0204; we == 1'b0; });
        finish_item(req);

        // 3. Write random Data Byte to SPI Master (0x300)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0300; we == 1'b1; });
        finish_item(req);

        // 4. Read SPI status/busy (0x304) — exercises the last uncovered
        //    register address.
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0304; we == 1'b0; });
        finish_item(req);

        // 5. Wait for the (test-only, STALL_WINDOW-shortened) stall window
        //    to elapse so the fail-safe logic actually trips.
        #700ns;

        // 6. Read stall status (0x208) — expect stall_flag == 1
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0208; we == 1'b0; });
        finish_item(req);

        // 7. Write 1 to clear the stall flag (0x208)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0208; we == 1'b1; wdata[0] == 1'b1; });
        finish_item(req);

        // 8. Read stall status again — expect stall_flag == 0 (recovered)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        void'(req.randomize() with { addr == 32'h0000_0208; we == 1'b0; });
        finish_item(req);
    endtask
endclass
