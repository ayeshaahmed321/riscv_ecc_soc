module axi_ecc_memory (
    input  logic        aclk,
    input  logic        aresetn,

    // Write Channels
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,

    // Read Channels
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // Internal SRAM Connections
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic        mem_we,
    input  logic [31:0] ecc_rdata
);

    logic read_pending; // Tracks the 1-cycle SRAM delay

    assign awready = awvalid && wvalid && !bvalid;
    assign wready  = awvalid && wvalid && !bvalid;
    assign arready = arvalid && !rvalid && !read_pending; // Wait if read is in progress

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bvalid       <= 1'b0;
            bresp        <= 2'b00;
            rvalid       <= 1'b0;
            rresp        <= 2'b00;
            rdata        <= 32'h0;
            mem_we       <= 1'b0;
            mem_addr     <= 32'h0;
            mem_wdata    <= 32'h0;
            read_pending <= 1'b0;
        end else begin
            mem_we <= 1'b0; // Default pulse deassertion

            // Write Channel Logic
            if (awvalid && wvalid && !bvalid) begin
                mem_addr  <= awaddr;
                mem_wdata <= wdata;
                mem_we    <= 1'b1;
                bvalid    <= 1'b1;
                bresp     <= 2'b00; // OKAY
            end else if (bready && bvalid) begin
                bvalid    <= 1'b0;
            end

            // Read Channel Logic (Fixed Latency)
            if (arvalid && arready) begin
                mem_addr     <= araddr;
                read_pending <= 1'b1;      // Step 1: Send address, wait 1 tick
            end else if (read_pending) begin
                rdata        <= ecc_rdata; // Step 2: Capture the newly fetched data
                rvalid       <= 1'b1;
                rresp        <= 2'b00;
                read_pending <= 1'b0;
            end else if (rready && rvalid) begin
                rvalid       <= 1'b0;
            end
        end
    end
endmodule