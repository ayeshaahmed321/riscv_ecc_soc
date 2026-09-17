module amba_interconnect (
    input  logic        clk, reset,
    
    // CPU Interface
    input  logic        mem_req,
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    input  logic        cpu_we,
    output logic [31:0] cpu_rdata,
    output logic        cpu_stall,

    // AXI-Lite Master 
    output logic [31:0] awaddr, output logic awvalid, input  logic awready,
    output logic [31:0] wdata,  output logic wvalid,  input  logic wready,
    input  logic [1:0]  bresp,  input  logic bvalid,  output logic bready,
    output logic [31:0] araddr, output logic arvalid, input  logic arready,
    input  logic [31:0] rdata,  input  logic [1:0] rresp, input  logic rvalid, output logic rready,

    // APB Shared Master Bus 
    output logic        penable, pwrite,
    output logic [31:0] paddr, pwdata,
    
    // APB Slaves
    output logic        psel_ecc,   input logic [31:0] prdata_ecc,   input logic pready_ecc,
    output logic        psel_motor, input logic [31:0] prdata_motor, input logic pready_motor,
    output logic        psel_spi,   input logic [31:0] prdata_spi,   input logic pready_spi
);

    // Defined the formal 4-state architecture
    typedef enum logic [1:0] {IDLE, AXI_WAIT, APB_SETUP, APB_ACCESS} state_t;
    state_t state, next_state;

    logic is_axi, is_apb, is_ecc, is_motor, is_spi;
    assign is_axi   = (cpu_addr < 32'h100);
    assign is_apb   = (cpu_addr >= 32'h100);
    assign is_ecc   = (cpu_addr >= 32'h100 && cpu_addr < 32'h200);
    assign is_motor = (cpu_addr >= 32'h200 && cpu_addr < 32'h300);
    assign is_spi   = (cpu_addr >= 32'h300 && cpu_addr < 32'h400);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else       state <= next_state;
    end

    always_comb begin
        next_state = state;
        cpu_stall  = 1'b0;
        cpu_rdata  = 32'h0;
        
        awaddr = cpu_addr; awvalid = 0; wdata = cpu_wdata; wvalid = 0; bready = 0;
        araddr = cpu_addr; arvalid = 0; rready = 0;
        
        paddr = cpu_addr; pwdata = cpu_wdata; pwrite = cpu_we; penable = 0;
        psel_ecc = 0; psel_motor = 0; psel_spi = 0;

        case (state)
            IDLE: begin
                if (mem_req) begin
                    cpu_stall = 1'b1; 
                    if (is_axi) next_state = AXI_WAIT;
                    if (is_apb) next_state = APB_SETUP; // Route to Phase 1
                end
            end

            AXI_WAIT: begin
                cpu_stall = 1'b1;
                if (cpu_we) begin
                    awvalid = 1'b1; wvalid = 1'b1; bready = 1'b1;
                    if (bvalid) begin
                        cpu_stall = 1'b0; 
                        next_state = IDLE;
                    end
                end else begin
                    arvalid = 1'b1; rready = 1'b1;
                    if (rvalid) begin
                        cpu_rdata = rdata;
                        cpu_stall = 1'b0; 
                        next_state = IDLE;
                    end
                end
            end

            // Phase 1: Setup
            APB_SETUP: begin
                cpu_stall = 1'b1; // Keep CPU frozen
                if (is_ecc) psel_ecc = 1'b1;
                else if (is_motor) psel_motor = 1'b1;
                else if (is_spi) psel_spi = 1'b1;
                next_state = APB_ACCESS;
            end

            // Phase 2: Access
            APB_ACCESS: begin
                cpu_stall = 1'b1;
                penable = 1'b1; // Assert enable 
                
                if (is_ecc) begin
                    psel_ecc = 1'b1;
                    if (pready_ecc) begin
                        cpu_rdata = prdata_ecc;
                        cpu_stall = 1'b0; // Release CPU safely
                        next_state = IDLE;
                    end
                end 
                else if (is_motor) begin
                    psel_motor = 1'b1;
                    if (pready_motor) begin
                        cpu_rdata = prdata_motor;
                        cpu_stall = 1'b0; // Release CPU safely
                        next_state = IDLE;
                    end
                end 
                else if (is_spi) begin
                    psel_spi = 1'b1;
                    if (pready_spi) begin
                        cpu_rdata = prdata_spi;
                        cpu_stall = 1'b0; // Release CPU safely
                        next_state = IDLE;
                    end
                end
                else begin
                    cpu_stall = 1'b0;
                    next_state = IDLE; 
                end
            end
        endcase
    end
endmodule