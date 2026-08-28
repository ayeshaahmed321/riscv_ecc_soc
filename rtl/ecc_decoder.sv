module ecc_decoder(
    input  logic [38:0] ecc_in,
    output logic [31:0] data_out,
    output logic        single_error,
    output logic        double_error
);
    logic [38:1] c;
    logic p_in;
    logic [5:0] syndrome;
    logic p_overall;
    logic [38:1] corrected_c;

    assign {c, p_in} = ecc_in; 

    // Calculate syndrome to know address of data where there was an error
    assign syndrome[0] = c[1]^c[3]^c[5]^c[7]^c[9]^c[11]^c[13]^c[15]^c[17]^c[19]^c[21]^c[23]^c[25]^c[27]^c[29]^c[31]^c[33]^c[35]^c[37];
    assign syndrome[1] = c[2]^c[3]^c[6]^c[7]^c[10]^c[11]^c[14]^c[15]^c[18]^c[19]^c[22]^c[23]^c[26]^c[27]^c[30]^c[31]^c[34]^c[35]^c[38];
    assign syndrome[2] = c[4]^c[5]^c[6]^c[7]^c[12]^c[13]^c[14]^c[15]^c[20]^c[21]^c[22]^c[23]^c[28]^c[29]^c[30]^c[31]^c[36]^c[37]^c[38];
    assign syndrome[3] = c[8]^c[9]^c[10]^c[11]^c[12]^c[13]^c[14]^c[15]^c[24]^c[25]^c[26]^c[27]^c[28]^c[29]^c[30]^c[31];
    assign syndrome[4] = c[16]^c[17]^c[18]^c[19]^c[20]^c[21]^c[22]^c[23]^c[24]^c[25]^c[26]^c[27]^c[28]^c[29]^c[30]^c[31];
    assign syndrome[5] = c[32]^c[33]^c[34]^c[35]^c[36]^c[37]^c[38];

    // Check the overall parity to find if there was a one bit or a two bit error
    assign p_overall = (^c) ^ p_in; 

    always_comb begin
        single_error = 1'b0;
        double_error = 1'b0;
        corrected_c = c;

        if (syndrome != 0) begin
            if (p_overall == 1'b1) begin
                single_error = 1'b1;       // This means there was a 1 bit error
                if (syndrome <= 38) begin
                    corrected_c[syndrome] = ~corrected_c[syndrome]; // Correct the error
                end
            end else begin
                double_error = 1'b1;       // found a two bit error. This can't be fixed.
            end
        end else if (p_overall == 1'b1) begin
             single_error = 1'b1;          // The parity bit itself got corrupted and flipped, while the 39 bit data was the same.
        end

        // Final corrected data in case of 1 bit error
        data_out = {corrected_c[38], corrected_c[37], corrected_c[36], corrected_c[35], corrected_c[34], corrected_c[33], corrected_c[31], corrected_c[30], corrected_c[29], corrected_c[28], corrected_c[27], corrected_c[26], corrected_c[25], corrected_c[24], corrected_c[23], corrected_c[22], corrected_c[21], corrected_c[20], corrected_c[19], corrected_c[18], corrected_c[17], corrected_c[15], corrected_c[14], corrected_c[13], corrected_c[12], corrected_c[11], corrected_c[10], corrected_c[9], corrected_c[7], corrected_c[6], corrected_c[5], corrected_c[3]};
    end
endmodule