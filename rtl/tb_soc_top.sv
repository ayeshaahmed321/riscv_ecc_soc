module tb_soc_top;
    logic clk;
    logic reset;
    
    // New Physical I/O
    logic pwm_out, tacho_in;
    logic sclk, mosi, miso, cs_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        tacho_in = 0;
        miso = 1; // Simulate external SPI chip sending data back
        #10 reset = 0;
    end

    soc_top dut (
        .clk(clk),
        .reset(reset),
        .pwm_out(pwm_out),
        .tacho_in(tacho_in),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );
endmodule