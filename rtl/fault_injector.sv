module fault_injector (
    input  logic [38:0] data_in,
    input  logic [38:0] fault_mask, // Put a 1 here to flip a bit
    output logic [38:0] data_out
);
    // XOR both to obtain a 1, which shows that a bit is different
    assign data_out = data_in ^ fault_mask;
endmodule