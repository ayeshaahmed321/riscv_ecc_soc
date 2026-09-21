import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_bus_monitor)

    virtual cpu_bus_if vif;
    uvm_analysis_port #(cpu_bus_seq_item) ap;

    function new(string name = "cpu_bus_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_bus_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        cpu_bus_seq_item trans;
        logic req_q; // registered copy of req, used to detect its falling edge cleanly

        req_q = 1'b0;
        forever begin
            @(posedge vif.clk);

            // A transaction is complete exactly on the cycle the driver drops
            // req (it only does this once, after stall has cleared) — this
            // is a clean single-fire condition, unlike "prev_req && !stall"
            // which raced against the driver's own stall-polling loop and
            // fired on two consecutive edges for one transaction.
            if (req_q && !vif.req) begin
                trans = cpu_bus_seq_item::type_id::create("trans");
                trans.addr  = vif.addr;
                trans.we    = vif.we;
                trans.wdata = vif.wdata;
                trans.rdata = vif.rdata;

                // Peripheral telemetry snapshot at completion time
                trans.pwm_out      = vif.pwm_out;
                trans.rpm_pulse_in = vif.tacho_in;
                trans.spi_mosi     = vif.mosi;
                trans.spi_miso     = vif.miso;
                trans.spi_sclk     = vif.sclk;
                trans.cpu_stall    = vif.nmi_stall; // reuse field: fail-safe flag

                ap.write(trans);
            end
            req_q = vif.req;
        end
    endtask
endclass
