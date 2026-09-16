module apb_ecc_registers (
    input  logic        pclk,
    input  logic        presetn,
    
    // APB Slave Interface
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    // Internal Connections to ECC Flags/Masks
    output logic [38:0] fault_mask,
    input  logic        single_err,
    input  logic        double_err
);

    assign pready  = 1'b1;  // Zero wait-state peripheral
    assign pslverr = 1'b0;  // No error responses generated

    // Write Logic (Access Phase)
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            fault_mask <= 39'h0;
        end else if (psel && penable && pwrite) begin
            if (paddr == 32'h0000_0100) begin
                // Zero-extend 32-bit pwdata to 39 bits to eliminate out-of-bounds X propagation
                fault_mask <= {7'b0, pwdata};
            end
        end
    end

    // Read Logic (Combinational)
    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            if (paddr == 32'h0000_0100) begin
                prdata = fault_mask[31:0];
            end else if (paddr == 32'h0000_0104) begin
                prdata = {30'h0, double_err, single_err}; // Status dashboard
            end
        end
    end
endmodule