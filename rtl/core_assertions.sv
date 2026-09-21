// core_assertions.sv — SVA bound to rv32i_core.
module rv32i_core_assertions (
    input logic        clk,
    input logic        reset,
    input logic [31:0] pc,
    input logic        mem_req
);
    property p_pc_word_aligned;
        @(posedge clk) disable iff (reset) pc[1:0] == 2'b00;
    endproperty
    assert property (p_pc_word_aligned)
        else $error("SVA VIOLATION [rv32i_core]: pc is not word-aligned: 0x%08h", pc);

    property p_no_mem_req_during_reset;
        @(posedge clk) reset |-> !mem_req;
    endproperty
    assert property (p_no_mem_req_during_reset)
        else $error("SVA VIOLATION [rv32i_core]: mem_req asserted while in reset");
endmodule

bind rv32i_core rv32i_core_assertions rv32i_core_sva_inst (.*);
