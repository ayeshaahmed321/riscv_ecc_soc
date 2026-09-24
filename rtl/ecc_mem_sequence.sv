class ecc_mem_sequence extends uvm_sequence #(ecc_mem_seq_item);
    `uvm_object_utils(ecc_mem_sequence)

    function new(string name = "ecc_mem_sequence");
        super.new(name);
    endfunction

    task automatic do_write(input logic [31:0] addr, input logic [31:0] data);
        ecc_mem_seq_item req;
        req = ecc_mem_seq_item::type_id::create("write_req");
        start_item(req);
        if (!req.randomize() with {
            we == 1'b1;
            addr == local::addr;
            wdata == local::data;
            fault_mask == 39'h0;
        })
            `uvm_fatal("SEQ", "ECC write randomization failed")
        finish_item(req);
    endtask

    task automatic do_read(input logic [31:0] addr, input logic [38:0] mask);
        ecc_mem_seq_item req;
        req = ecc_mem_seq_item::type_id::create("read_req");
        start_item(req);
        if (!req.randomize() with {
            we == 1'b0;
            addr == local::addr;
            fault_mask == local::mask;
        })
            `uvm_fatal("SEQ", "ECC read randomization failed")
        finish_item(req);
    endtask

    task body();
        logic [38:0] mask;

        // One known word is used for deterministic ECC checking.
        do_write(32'h0000_0000, 32'h1234_5678);

        // Clean read.
        do_read(32'h0000_0000, 39'h0);

        // Every ECC codeword bit gets a deterministic single-bit test.
        for (int bit_idx = 0; bit_idx < 39; bit_idx++) begin
            mask = 39'h0;
            mask[bit_idx] = 1'b1;
            do_read(32'h0000_0000, mask);
        end

        // Representative double-bit cases, including high check bits.
        do_read(32'h0000_0000, 39'b000000000000000000000000000000000000011);
        do_read(32'h0000_0000, 39'b000000000000000000000000000000001000001);
        do_read(32'h0000_0000, 39'b100000000000000000000000000000000000001);

        // Additional randomized read/write pairs inside the real SRAM window.
        repeat (100) begin
            ecc_mem_seq_item req;
            logic [31:0] safe_addr;

            req = ecc_mem_seq_item::type_id::create("rand_write");
            start_item(req);
            if (!req.randomize() with { we == 1'b1; })
                `uvm_fatal("SEQ", "Random write randomization failed")
            safe_addr = req.addr;
            finish_item(req);

            req = ecc_mem_seq_item::type_id::create("rand_read");
            start_item(req);
            if (!req.randomize() with {
                we == 1'b0;
                addr == local::safe_addr;
            })
                `uvm_fatal("SEQ", "Random read randomization failed")
            finish_item(req);
        end
    endtask
endclass
