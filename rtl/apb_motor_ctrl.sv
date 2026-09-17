module apb_motor_ctrl (
    input  logic        pclk,
    input  logic        presetn,
    
    // APB Slave Interface
    input  logic        psel, penable, pwrite,
    input  logic [31:0] paddr, pwdata,
    output logic [31:0] prdata, pready,

    // Motor I/O
    output logic        pwm_out,
    input  logic        tacho_in, // From RPM sensor
    output logic        nmi_stall // Hardware interrupt to CPU
);

    assign pready = 1'b1;

    // Registers
    logic [7:0]  duty_cycle;
    logic [31:0] rpm_count;
    logic        stall_flag;

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
            duty_cycle <= 8'h0;
            stall_flag <= 1'b0;
        end else if (psel && penable && pwrite) begin
            if (paddr == 32'h0000_0200) duty_cycle <= pwdata[7:0];
            // Clear stall flag if CPU writes 1 to the status register
            if (paddr == 32'h0000_0208 && pwdata[0]) stall_flag <= 1'b0; 
        end else if (stall_trigger) begin
            stall_flag <= 1'b1; // Hardware sets the flag automatically
        end
    end

    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            case (paddr)
                32'h0000_0200: prdata = {24'h0, duty_cycle};
                32'h0000_0204: prdata = rpm_count;
                32'h0000_0208: prdata = {31'h0, stall_flag};
            endcase
        end
    end

    // --- 2. PWM Generation & Fail-Safe ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) pwm_counter <= 8'h0;
        else          pwm_counter <= pwm_counter + 1;
    end
    
    // Fail-Safe: If stall is detected, physically sever the PWM output
    assign pwm_out = (stall_flag) ? 1'b0 : (pwm_counter < duty_cycle);
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

            if (window_timer == 20'd1_000_000) begin
                window_timer <= 0;
                rpm_count <= edge_counter; // Update readable RPM register
                edge_counter <= 0;         // Reset for next window
                
                // Stall Logic: If we are driving the motor, but RPM is 0
                if (duty_cycle > 8'd10 && edge_counter == 0) begin
                    stall_trigger <= 1'b1;
                end
            end else begin
                window_timer <= window_timer + 1;
            end
        end
    end
endmodule