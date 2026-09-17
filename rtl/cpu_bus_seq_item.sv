import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_seq_item extends uvm_sequence_item;
    `uvm_object_utils(cpu_bus_seq_item)

    rand logic [31:0] addr;
    rand logic [31:0] wdata;
    rand logic        we;
    logic [31:0]      rdata;

    // Constrain random traffic to only hit the Motor and SPI address spaces
    constraint peripheral_addr_c {
        addr inside {
            [32'h0000_0200 : 32'h0000_0208], // Motor Control Registers
            [32'h0000_0300 : 32'h0000_0304]  // SPI Master Registers
        };
    }

    function new(string name = "cpu_bus_seq_item");
        super.new(name);
    endfunction
endclass