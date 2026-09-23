module apb_motor_ctrl #(
    parameter logic [19:0] STALL_WINDOW      = 20'd1_000_000,
    parameter logic [19:0] PROFILE_STEP_TIME = 20'd200_000 // cycles per profile step (test-overridable)
) (
    input  logic        pclk,
    input  logic        presetn,

    // APB Slave Interface
    input  logic        psel, penable, pwrite,
    input  logic [31:0] paddr, pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    // Motor I/O
    output logic        pwm_out,
    input  logic        tacho_in, // From RPM sensor
    output logic        nmi_stall // Hardware interrupt to CPU
);

    assign pready = 1'b1;

    // Registers
    logic [7:0]  duty_cycle;      // manual duty-cycle register (0x200)
    logic [31:0] rpm_count;
    logic        stall_flag;

    // --- Profile loading (0x210-0x22C: 8 duty steps, 0x230: control,
    //     0x234: status). Loading a profile and starting it lets the motor
    //     ramp through a sequence of duty-cycle steps automatically instead
    //     of the CPU having to rewrite 0x200 on every step.
    logic [7:0]  profile_mem [0:7];
    logic        profile_running;
    logic [2:0]  profile_index;
    logic [19:0] profile_step_timer;
    logic [7:0]  effective_duty;  // what actually drives PWM/stall logic

    assign effective_duty = profile_running ? profile_mem[profile_index] : duty_cycle;

    // Internal Signals (Declared before use)
    logic        stall_trigger;
    logic [7:0]  pwm_counter;
    logic [19:0] window_timer;
    logic [31:0] edge_counter;
    logic        tacho_sync1, tacho_sync2;
    wire         tacho_edge;

    // --- 1. APB Read/Write Interface ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            duty_cycle      <= 8'h0;
            stall_flag      <= 1'b0;
            profile_running <= 1'b0;
            profile_index   <= 3'd0;
            for (int i = 0; i < 8; i++) profile_mem[i] <= 8'h0;
        end else if (psel && penable && pwrite) begin
            if (paddr == 32'h0000_0200) duty_cycle <= pwdata[7:0];
            // Clear stall flag if CPU writes 1 to the status register
            if (paddr == 32'h0000_0208 && pwdata[0]) stall_flag <= 1'b0;

            // Load one profile step: word address 0x210 + 4*i, i in [0:7]
            if (paddr >= 32'h0000_0210 && paddr <= 32'h0000_022C && paddr[1:0] == 2'b00)
                profile_mem[(paddr - 32'h0000_0210) >> 2] <= pwdata[7:0];

            // Start the profile sequencer
            if (paddr == 32'h0000_0230 && pwdata[0] && !profile_running) begin
                profile_running <= 1'b1;
                profile_index   <= 3'd0;
            end
        end else if (stall_trigger) begin
            stall_flag <= 1'b1; // Hardware sets the flag automatically
        end

        // Profile step advance (independent of APB access this cycle)
        if (presetn && profile_running) begin
            if (profile_step_timer == PROFILE_STEP_TIME) begin
                profile_step_timer <= 20'd0;
                if (profile_index == 3'd7) begin
                    profile_running <= 1'b0; // sequence complete
                end else begin
                    profile_index <= profile_index + 3'd1;
                end
            end else begin
                profile_step_timer <= profile_step_timer + 20'd1;
            end
        end else if (!profile_running) begin
            profile_step_timer <= 20'd0;
        end
    end

    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            if (paddr == 32'h0000_0200) prdata = {24'h0, duty_cycle};
            else if (paddr == 32'h0000_0204) prdata = rpm_count;
            else if (paddr == 32'h0000_0208) prdata = {31'h0, stall_flag};
            else if (paddr >= 32'h0000_0210 && paddr <= 32'h0000_022C && paddr[1:0] == 2'b00)
                prdata = {24'h0, profile_mem[(paddr - 32'h0000_0210) >> 2]};
            else if (paddr == 32'h0000_0230) prdata = {31'h0, profile_running};
            else if (paddr == 32'h0000_0234) prdata = {29'h0, profile_index};
        end
    end

    // --- 2. PWM Generation & Fail-Safe ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) pwm_counter <= 8'h0;
        else          pwm_counter <= pwm_counter + 1;
    end

    // Fail-Safe: If stall is detected, physically sever the PWM output
    assign pwm_out = (stall_flag) ? 1'b0 : (pwm_counter < effective_duty);
    assign nmi_stall = stall_flag;

    // --- 3. RPM Measurement & Stall Detection ---
    // Synchronize async tachometer input to prevent metastability
    always_ff @(posedge pclk) begin
        tacho_sync1 <= tacho_in;
        tacho_sync2 <= tacho_sync1;
    end
    assign tacho_edge = tacho_sync1 & ~tacho_sync2;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            window_timer <= 0;
            edge_counter <= 0;
            rpm_count <= 0;
            stall_trigger <= 0;
        end else begin
            stall_trigger <= 1'b0; // Default pulse

            if (tacho_edge) edge_counter <= edge_counter + 1;

            if (window_timer == STALL_WINDOW) begin
                window_timer <= 0;
                rpm_count <= edge_counter; // Update readable RPM register
                edge_counter <= 0;         // Reset for next window

                // Stall Logic: If we are driving the motor, but RPM is 0
                if (effective_duty > 8'd10 && edge_counter == 0) begin
                    stall_trigger <= 1'b1;
                end
            end else begin
                window_timer <= window_timer + 1;
            end
        end
    end
endmodule
