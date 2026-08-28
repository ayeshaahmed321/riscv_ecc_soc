module sram_memory #(
    parameter DEPTH = 64,       
    parameter ADDR_WIDTH = 6    
)(
    input  logic                  clk,
    input  logic                  we,       
    input  logic [ADDR_WIDTH-1:0] addr,     
    input  logic [38:0]           data_in,  
    output logic [38:0]           data_out  
);
    // Initialize array at declaration
    logic [38:0] mem_array [0:DEPTH-1] = '{default: '0};

    // Synchronous write
    always_ff @(posedge clk) begin
        if (we) mem_array[addr] <= data_in;
    end

    // Asynchronous read
    assign data_out = mem_array[addr]; 

endmodule