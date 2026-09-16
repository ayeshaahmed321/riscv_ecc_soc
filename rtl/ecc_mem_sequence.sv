class ecc_mem_sequence extends uvm_sequence #(ecc_mem_seq_item);
    `uvm_object_utils(ecc_mem_sequence)

    function new(string name = "ecc_mem_sequence");
        super.new(name);
    endfunction

    task body();
        ecc_mem_seq_item req;
        logic [31:0] safe_addr;

        // Generate 50 matched Write/Read pairs (100 transactions total)
        repeat(50) begin
            // 1. WRITE Operation
            req = ecc_mem_seq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { we == 1'b1; }) begin
                `uvm_fatal("SEQ", "Write randomization failed")
            end
            safe_addr = req.addr; // Save the newly initialized address
            finish_item(req);

            // 2. READ Operation (to the exact same address)
            req = ecc_mem_seq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { we == 1'b0; addr == safe_addr; }) begin
                `uvm_fatal("SEQ", "Read randomization failed")
            end
            finish_item(req);
        end
    endtask
endclass