// ecc_assertions.sv — SVA bound to ecc_decoder (combinational, no clk port
// on the DUT itself, so this uses an immediate assertion re-checked on
// every input change rather than a clocked property).
module ecc_decoder_assertions (
    input logic single_error,
    input logic double_error
);
    always_comb begin
        assert (!(single_error && double_error))
            else $error("SVA VIOLATION [ecc_decoder]: single_error and double_error asserted simultaneously — SECDED decode is broken");
    end
endmodule

bind ecc_decoder ecc_decoder_assertions ecc_decoder_sva_inst (.*);
