module ecc_encoder (
    input  logic [31:0] data_in,
    output logic [38:0] ecc_out 
);
    logic [38:1] c; 
    logic p_overall;
    
    always_comb begin
        c = '0; 
        
        c[3] = data_in[0]; c[5] = data_in[1]; c[6] = data_in[2]; c[7] = data_in[3];
        c[9] = data_in[4]; c[10]= data_in[5]; c[11]= data_in[6]; c[12]= data_in[7];
        c[13]= data_in[8]; c[14]= data_in[9]; c[15]= data_in[10]; c[17]= data_in[11];
        c[18]= data_in[12]; c[19]= data_in[13]; c[20]= data_in[14]; c[21]= data_in[15];
        c[22]= data_in[16]; c[23]= data_in[17]; c[24]= data_in[18]; c[25]= data_in[19];
        c[26]= data_in[20]; c[27]= data_in[21]; c[28]= data_in[22]; c[29]= data_in[23];
        c[30]= data_in[24]; c[31]= data_in[25]; c[33]= data_in[26]; c[34]= data_in[27];
        c[35]= data_in[28]; c[36]= data_in[29]; c[37]= data_in[30]; c[38]= data_in[31];

        c[1]  = c[3]^c[5]^c[7]^c[9]^c[11]^c[13]^c[15]^c[17]^c[19]^c[21]^c[23]^c[25]^c[27]^c[29]^c[31]^c[33]^c[35]^c[37];
        c[2]  = c[3]^c[6]^c[7]^c[10]^c[11]^c[14]^c[15]^c[18]^c[19]^c[22]^c[23]^c[26]^c[27]^c[30]^c[31]^c[34]^c[35]^c[38];
        c[4]  = c[5]^c[6]^c[7]^c[12]^c[13]^c[14]^c[15]^c[20]^c[21]^c[22]^c[23]^c[28]^c[29]^c[30]^c[31]^c[36]^c[37]^c[38];
        c[8]  = c[9]^c[10]^c[11]^c[12]^c[13]^c[14]^c[15]^c[24]^c[25]^c[26]^c[27]^c[28]^c[29]^c[30]^c[31];
        c[16] = c[17]^c[18]^c[19]^c[20]^c[21]^c[22]^c[23]^c[24]^c[25]^c[26]^c[27]^c[28]^c[29]^c[30]^c[31];
        c[32] = c[33]^c[34]^c[35]^c[36]^c[37]^c[38];
        
        p_overall = ^c; 
        
        ecc_out = {c, p_overall}; 
    end
endmodule