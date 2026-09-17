import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_sequence extends uvm_sequence #(cpu_bus_seq_item);
    `uvm_object_utils(cpu_bus_sequence)

    function new(string name = "cpu_bus_sequence");
        super.new(name);
    endfunction

    task body();
        cpu_bus_seq_item req;

        // 1. Write random Duty Cycle to Motor (0x200)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        req.randomize() with { addr == 32'h0000_0200; we == 1'b1; };
        finish_item(req);

        // 2. Read RPM Count (0x204)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        req.randomize() with { addr == 32'h0000_0204; we == 1'b0; };
        finish_item(req);

        // 3. Write random Data Byte to SPI Master (0x300)
        req = cpu_bus_seq_item::type_id::create("req");
        start_item(req);
        req.randomize() with { addr == 32'h0000_0300; we == 1'b1; };
        finish_item(req);
    endtask
endclass