module apb_ecc_registers (
    input  logic        pclk,
    input  logic        presetn,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,
    output logic [38:0] fault_mask,
    input  logic        single_err,
    input  logic        double_err
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // 0x100: fault_mask[31:0]
    // 0x110: fault_mask[38:32]
    // 0x104: live ECC status {double_err,single_err}
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            fault_mask <= 39'h0;
        end
        else if (psel && penable && pwrite) begin
            if (paddr == 32'h0000_0100)
                fault_mask[31:0] <= pwdata;
            else if (paddr == 32'h0000_0110)
                fault_mask[38:32] <= pwdata[6:0];
        end
    end

    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            case (paddr)
                32'h0000_0100: prdata = fault_mask[31:0];
                32'h0000_0104: prdata = {30'h0, double_err, single_err};
                32'h0000_0110: prdata = {25'h0, fault_mask[38:32]};
                default:       prdata = 32'h0;
            endcase
        end
    end
endmodule
