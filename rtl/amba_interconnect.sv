module amba_interconnect (
    input  logic        clk, reset,
    
    // CPU Interface
    input  logic        mem_req,   // High if instruction is LOAD or STORE
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    input  logic        cpu_we,
    output logic [31:0] cpu_rdata,
    output logic        cpu_stall,

    // AXI-Lite Master (To SRAM)
    output logic [31:0] awaddr, output logic awvalid, input  logic awready,
    output logic [31:0] wdata,  output logic wvalid,  input  logic wready,
    input  logic [1:0]  bresp,  input  logic bvalid,  output logic bready,
    output logic [31:0] araddr, output logic arvalid, input  logic arready,
    input  logic [31:0] rdata,  input  logic [1:0] rresp, input  logic rvalid, output logic rready,

    // APB Master (To Registers)
    output logic        psel, penable, pwrite,
    output logic [31:0] paddr, pwdata,
    input  logic [31:0] prdata, input logic pready
);

    typedef enum logic [1:0] {IDLE, AXI_WAIT, APB_WAIT} state_t;
    state_t state, next_state;

    // Address Decoding Map
    logic is_axi, is_apb;
    assign is_axi = (cpu_addr < 32'h100);
    assign is_apb = (cpu_addr >= 32'h100);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    always_comb begin
        // Default assignments to prevent latches
        next_state = state;
        cpu_stall  = 1'b0;
        cpu_rdata  = 32'h0;
        
        // AXI Defaults
        awaddr = cpu_addr; awvalid = 0; wdata = cpu_wdata; wvalid = 0; bready = 0;
        araddr = cpu_addr; arvalid = 0; rready = 0;
        
        // APB Defaults
        paddr = cpu_addr; pwdata = cpu_wdata; pwrite = cpu_we; psel = 0; penable = 0;

        case (state)
            IDLE: begin
                if (mem_req) begin
                    cpu_stall = 1'b1; // Freeze CPU
                    if (is_axi) next_state = AXI_WAIT;
                    if (is_apb) next_state = APB_WAIT;
                end
            end

            AXI_WAIT: begin
                cpu_stall = 1'b1;
                if (cpu_we) begin
                    // AXI Write Handshake
                    awvalid = 1'b1; wvalid = 1'b1; bready = 1'b1;
                    if (bvalid) next_state = IDLE; // Write complete
                end else begin
                    // AXI Read Handshake
                    arvalid = 1'b1; rready = 1'b1;
                    if (rvalid) begin
                        cpu_rdata = rdata;
                        next_state = IDLE; // Read complete
                    end
                end
            end

            APB_WAIT: begin
                cpu_stall = 1'b1;
                psel = 1'b1; 
                penable = 1'b1; // Simplified APB access phase
                if (pready) begin
                    cpu_rdata = prdata;
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule