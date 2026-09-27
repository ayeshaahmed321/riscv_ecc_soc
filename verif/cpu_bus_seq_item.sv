import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_seq_item extends uvm_sequence_item;
    `uvm_object_utils(cpu_bus_seq_item)

    rand logic [31:0] addr;
    rand logic [31:0] wdata;
    rand logic        we;
    logic [31:0]      rdata;

    logic             pwm_out;
    logic             rpm_pulse_in;
    logic             spi_mosi;
    logic             spi_miso;
    logic             spi_sclk;
    logic             cpu_stall;

    // PWM observation window collected by the monitor.
    int unsigned pwm_samples;
    int unsigned pwm_high_samples;

    // SPI transfer observation collected by the monitor.
    logic [7:0] spi_tx_observed;
    logic [7:0] spi_rx_observed;
    logic       spi_transfer_done;
    logic       spi_rx_valid;

    constraint peripheral_addr_c {
        addr inside {
            [32'h0000_0200 : 32'h0000_0208],
            [32'h0000_0210 : 32'h0000_0234],
            [32'h0000_0300 : 32'h0000_0304]
        };
        addr[1:0] == 2'b00;
    }

    function new(string name = "cpu_bus_seq_item");
        super.new(name);
        pwm_samples = 0;
        pwm_high_samples = 0;
        spi_tx_observed = 0;
        spi_rx_observed = 0;
        spi_transfer_done = 0;
        spi_rx_valid = 0;
    endfunction
endclass
