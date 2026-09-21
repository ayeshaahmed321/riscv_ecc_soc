module apb_spi_master (
    input  logic        pclk,
    input  logic        presetn,

    // APB Slave Interface
    input  logic        psel, penable, pwrite,
    input  logic [31:0] paddr, pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    // SPI Physical Interface (Mode 0: CPOL=0, CPHA=0)
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs_n
);

    assign pready = 1'b1; // Zero wait-state for APB bus

    logic [7:0] shift_reg, rx_data;
    logic       busy;
    logic [2:0] bit_cnt;
    logic [3:0] clk_div;

    // --- 1. APB Write & SPI State Machine ---
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            shift_reg <= 8'h0;
            rx_data   <= 8'h0;
            busy      <= 1'b0;
            bit_cnt   <= 3'd7;
            clk_div   <= 4'h0;
            sclk      <= 1'b0;
            cs_n      <= 1'b1;
        end else begin
            // Trigger transfer on write to 0x300
            if (psel && penable && pwrite && (paddr == 32'h0000_0300) && !busy) begin
                shift_reg <= pwdata[7:0];
                busy      <= 1'b1;
                cs_n      <= 1'b0;  // Assert Chip Select (Active Low)
                bit_cnt   <= 3'd7;
            end
            
            // Background SPI Shifting Logic
            if (busy) begin
                clk_div <= clk_div + 1;
                
                // Toggle SPI Clock (Divide pclk by 16)
                if (clk_div == 4'd7) begin
                    sclk <= ~sclk;
                    
                    // Rising Edge: Sample MISO
                    if (!sclk) begin
                        shift_reg[0] <= miso;
                    end 
                    // Falling Edge: Shift out next MOSI bit
                    else begin
                        if (bit_cnt == 0) begin
                            busy    <= 1'b0;
                            cs_n    <= 1'b1;
                            rx_data <= {shift_reg[7:1], miso}; // Latch final byte
                        end else begin
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt   <= bit_cnt - 1;
                        end
                    end
                end
            end else begin
                sclk    <= 1'b0;
                clk_div <= 4'h0;
            end
        end
    end

    // MOSI is driven by the MSB of the shift register
    assign mosi = shift_reg[7];

    // --- 2. APB Read Interface ---
    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
            case (paddr)
                32'h0000_0300: prdata = {31'h0, busy};       // Read: 1 if shifting, 0 if idle
                32'h0000_0304: prdata = {24'h0, rx_data};    // Read: Last received byte
            endcase
        end
    end
endmodule