class ecc_mem_sequence extends uvm_sequence #(ecc_mem_seq_item);
    `uvm_object_utils(ecc_mem_sequence)

    function new(string name = "ecc_mem_sequence");
        super.new(name);
    endfunction

    task body();
        ecc_mem_seq_item req;

        // Generate 100 completely random write/read/fault operations
        repeat(100) begin
            req = ecc_mem_seq_item::type_id::create("req");
            
            start_item(req);
            
            // Randomize the item; if it fails, throw a fatal error
            if (!req.randomize()) begin
                `uvm_fatal("SEQ", "Randomization of sequence item failed")
            end
            
            finish_item(req);
        end
    endtask
endclass