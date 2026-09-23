// motor_assertions.sv — SVA bound to apb_motor_ctrl (fail-safe invariant).
module apb_motor_ctrl_assertions (
    input logic pclk,
    input logic nmi_stall,
    input logic pwm_out,
    input logic profile_running,
    input logic [2:0] profile_index,
    input logic [19:0] profile_step_timer,
    input logic psel,
    input logic penable,
    input logic pwrite,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic [31:0] prdata
);
    property p_failsafe_pwm_low_when_stalled;
        @(posedge pclk) nmi_stall |-> !pwm_out;
    endproperty

    assert property (p_failsafe_pwm_low_when_stalled)
        else $error("SVA VIOLATION [apb_motor_ctrl]: pwm_out is high while nmi_stall is asserted — fail-safe breach");

    // Diagnostic trace: print every change to the profile-sequencer state,
    // and every APB write this module sees, so a mismatch between expected
    // and actual profile_index can be traced to the exact triggering cycle.
    logic prev_running;
    logic [2:0] prev_index;
    initial begin
        prev_running = 1'b0;
        prev_index   = 3'd0;
    end
    always @(posedge pclk) begin
        if (psel && penable && pwrite)
            $display("[MOTOR-DBG] @%0t APB WRITE paddr=0x%08h pwdata=0x%08h", $time, paddr, pwdata);
        if (profile_running !== prev_running || profile_index !== prev_index) begin
            $display("[MOTOR-DBG] @%0t profile_running: %0b->%0b  profile_index: %0d->%0d  step_timer=%0d",
                      $time, prev_running, profile_running, prev_index, profile_index, profile_step_timer);
            prev_running = profile_running;
            prev_index   = profile_index;
        end
        // Narrow per-cycle trace around the read window that fails, to see
        // exactly what psel/penable/prdata do cycle-by-cycle.
        if ($time >= 1400 && $time <= 1560) begin
            $display("[MOTOR-CYC] @%0t psel=%0b penable=%0b pwrite=%0b paddr=0x%08h prdata=0x%08h profile_index=%0d",
                      $time, psel, penable, pwrite, paddr, prdata, profile_index);
        end
    end
endmodule

bind apb_motor_ctrl apb_motor_ctrl_assertions apb_motor_ctrl_sva_inst (.*);
