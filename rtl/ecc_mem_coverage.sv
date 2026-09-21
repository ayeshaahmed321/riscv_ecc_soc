class ecc_mem_coverage extends uvm_subscriber #(ecc_mem_seq_item);
    `uvm_component_utils(ecc_mem_coverage)

    ecc_mem_seq_item tr;
    int num_faults;
    logic [5:0] sram_word_idx; // matches sram_memory's actual addr[7:2] decode

    covergroup cg;
        option.per_instance = 1;
        option.goal = 100;

        cp_we: coverpoint tr.we {
            bins write = {1'b1};
            bins read  = {1'b0};
        }

        // How many bits fault_mask flips: 0 / 1 / 2 / 3+
        cp_num_faults: coverpoint num_faults {
            bins zero        = {0};
            bins single      = {1};
            bins double      = {2};
            bins triple_plus = {[3:$]};
        }

        cp_single_err: coverpoint tr.single_err {
            bins asserted     = {1'b1};
            bins not_asserted = {1'b0};
        }

        cp_double_err: coverpoint tr.double_err {
            bins asserted     = {1'b1};
            bins not_asserted = {1'b0};
        }

        cp_addr_region: coverpoint sram_word_idx {
            bins low_half  = {[0:31]};
            bins high_half = {[32:63]};
        }

        // The three scenarios the spec explicitly asks us to verify:
        // a clean read, a single-bit-corrected read, and a double-bit-
        // detected read. Named bins list only the reachable combinations,
        // instead of a full auto-cross (which included many combinations
        // that can never legitimately happen and were unreachable).
        x_read_fault_response: cross cp_num_faults, cp_single_err, cp_double_err {
            ignore_bins zero_but_single    = binsof(cp_num_faults.zero) && binsof(cp_single_err.asserted);
            ignore_bins zero_but_double    = binsof(cp_num_faults.zero) && binsof(cp_double_err.asserted);
            ignore_bins single_not_flagged = binsof(cp_num_faults.single) && binsof(cp_single_err.not_asserted);
            ignore_bins single_but_double  = binsof(cp_num_faults.single) && binsof(cp_double_err.asserted);
            ignore_bins double_but_single  = binsof(cp_num_faults.double) && binsof(cp_single_err.asserted);
            ignore_bins double_not_flagged = binsof(cp_num_faults.double) && binsof(cp_double_err.not_asserted);
            ignore_bins many_bit_unpredictable = binsof(cp_num_faults.triple_plus);
        }
    endgroup

    function new(string name = "ecc_mem_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg = new();
    endfunction

    // uvm_subscriber's analysis export calls write() on every monitor.ap.write()
    virtual function void write(ecc_mem_seq_item t);
        tr = t;
        num_faults = $countones(tr.fault_mask);
        sram_word_idx = tr.addr[7:2];
        cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("ecc_mem functional coverage = %0.2f%%", cg.get_coverage()), UVM_LOW)
    endfunction
endclass
