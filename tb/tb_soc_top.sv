module tb_soc_top();
    logic clk;
    logic reset;

    // Instantiate the Top Level
    soc_top dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Run Simulation
    initial begin
        $display("--- Starting RISC-V ECC System Execution ---");
        
        // Hold reset
        reset = 1;
        #15;
        reset = 0;
        
        // Let the program run for 10 clock cycles
        #100;
        
        $display("--- Execution Complete ---");
        $stop;
    end
endmodule