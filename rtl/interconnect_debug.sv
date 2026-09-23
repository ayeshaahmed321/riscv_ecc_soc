// interconnect_debug.sv — TEMPORARY diagnostic trace (remove after bug is
// found). Bound to amba_interconnect to see its internal state/cpu_rdata
// around the window where a profile-index read returns wrong data.
module amba_interconnect_debug (
    input logic clk,
    input logic mem_req,
    input logic [31:0] cpu_addr,
    input logic cpu_we,
    input logic [31:0] cpu_rdata,
    input logic cpu_stall,
    input logic [1:0] state
);
    always @(posedge clk) begin
        if ($time >= 1400 && $time <= 1560) begin
            $display("[ICONNECT-CYC] @%0t state=%0d mem_req=%0b cpu_we=%0b cpu_addr=0x%08h cpu_stall=%0b cpu_rdata=0x%08h",
                      $time, state, mem_req, cpu_we, cpu_addr, cpu_stall, cpu_rdata);
        end
    end
endmodule

bind amba_interconnect amba_interconnect_debug amba_interconnect_dbg_inst (.*);
