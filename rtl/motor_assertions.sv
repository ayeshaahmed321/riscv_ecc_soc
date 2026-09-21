// motor_assertions.sv — SVA bound to apb_motor_ctrl (fail-safe invariant).
module apb_motor_ctrl_assertions (
    input logic pclk,
    input logic nmi_stall,
    input logic pwm_out
);
    property p_failsafe_pwm_low_when_stalled;
        @(posedge pclk) nmi_stall |-> !pwm_out;
    endproperty

    assert property (p_failsafe_pwm_low_when_stalled)
        else $error("SVA VIOLATION [apb_motor_ctrl]: pwm_out is high while nmi_stall is asserted — fail-safe breach");
endmodule

bind apb_motor_ctrl apb_motor_ctrl_assertions apb_motor_ctrl_sva_inst (.*);
