import uvm_pkg::*;
`include "uvm_macros.svh"

class cpu_bus_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_bus_monitor)

    virtual cpu_bus_if vif;
    uvm_analysis_port #(cpu_bus_seq_item) ap;

    int unsigned pwm_samples;
    int unsigned pwm_high_samples;
    bit          pwm_window_active;
    logic [7:0]  pwm_high_256;
    int unsigned pwm_samples_256;

    logic        prev_spi_done; // Added edge detector

    function new(string name = "cpu_bus_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        pwm_samples = 0;
        pwm_high_samples = 0;
        pwm_window_active = 0;
        pwm_high_256 = 0;
        pwm_samples_256 = 0;
        prev_spi_done = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_bus_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get virtual cpu_bus_if from config_db")
    endfunction

    task run_phase(uvm_phase phase);
        cpu_bus_seq_item trans;

        forever begin
            @(posedge vif.clk);

            // 1. PWM observation (Independent of bus reqs)
            if (pwm_window_active && pwm_samples_256 < 256) begin
                pwm_samples_256++;
                if (vif.pwm_out)
                    pwm_high_256++;
            end

            // 2. SPI Physical Observation (Edge-detected to prevent log spam)
            if (vif.spi_capture_done && !prev_spi_done) begin
                `uvm_info("MON_SPI", $sformatf("SPI capture done: TX=0x%02h RX=0x%02h bits=%0d", vif.spi_captured_tx, vif.spi_captured_rx, vif.spi_capture_bits), UVM_LOW)
            end
            prev_spi_done = vif.spi_capture_done;

            // 3. CPU Bus Observation
            if (vif.req && !vif.stall) begin
                trans = cpu_bus_seq_item::type_id::create("trans");
                trans.addr  = vif.addr;
                trans.we    = vif.we;
                trans.wdata = vif.wdata;
                trans.rdata = vif.rdata;

                trans.pwm_out       = vif.pwm_out;
                trans.rpm_pulse_in  = vif.tacho_in;
                trans.spi_mosi      = vif.mosi;
                trans.spi_miso      = vif.miso;
                trans.spi_sclk      = vif.sclk;
                trans.cpu_stall     = vif.nmi_stall;

                trans.pwm_samples       = pwm_samples_256;
                trans.pwm_high_samples  = pwm_high_256;
                
                // Attach the physical SPI telemetry to the bus transaction
                trans.spi_tx_observed   = vif.spi_captured_tx;
                trans.spi_rx_observed   = vif.spi_captured_rx;
                trans.spi_transfer_done = vif.spi_capture_done;
                trans.spi_rx_valid      = vif.spi_capture_done;

                ap.write(trans);

                if (vif.we && vif.addr == 32'h0000_0200) begin
                    pwm_window_active = 1'b1;
                    pwm_samples_256 = 0;
                    pwm_high_256 = 0;
                end
            end
        end
    endtask
endclass