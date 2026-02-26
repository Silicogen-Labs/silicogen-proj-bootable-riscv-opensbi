`timescale 1ns / 1ps

module tb_soc(
    input logic clk,
    input logic rst_n
);
    // Clock and reset driven from C++
    
    // UART interface
    logic uart_tx;
    
    // Test program selection (can be overridden with +define+TEST_PROGRAM=...)
    `ifndef TEST_PROGRAM
        `define TEST_PROGRAM "build/hello.hex"
    `endif
    
    // Instantiate the SoC with test program loaded
    riscv_soc #(
        .MEM_INIT_FILE(`TEST_PROGRAM)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // Clock generation: Driven from C++ sim_main.cpp
    // (50MHz = 20ns period, 10ns per edge)
    
    // UART monitor - capture transmitted characters
    logic [7:0] uart_char;
    logic uart_valid;
    int uart_bit_count;
    logic uart_tx_prev;
    logic [9:0] uart_shift_reg;
    int uart_baud_counter;
    
    // UART receiver logic (115200 baud at 50MHz = 434 clocks per bit)
    localparam UART_CLKS_PER_BIT = 434;
    
    initial begin
        uart_tx_prev = 1;
        uart_bit_count = 0;
        uart_baud_counter = 0;
        uart_valid = 0;
    end
    
    always @(posedge clk) begin
        uart_tx_prev <= uart_tx;
        uart_valid <= 0;
        
        // Detect start bit (falling edge)
        if (uart_tx_prev && !uart_tx && uart_bit_count == 0) begin
            uart_bit_count <= 1;
            uart_baud_counter <= UART_CLKS_PER_BIT / 2; // Sample in middle of bit
        end
        // Sample data bits
        else if (uart_bit_count > 0) begin
            if (uart_baud_counter == 0) begin
                uart_shift_reg[uart_bit_count-1] <= uart_tx;
                uart_bit_count <= uart_bit_count + 1;
                uart_baud_counter <= UART_CLKS_PER_BIT;
                
                // After receiving all 10 bits (start + 8 data + stop)
                if (uart_bit_count == 10) begin
                    uart_char <= uart_shift_reg[8:1]; // Extract data bits
                    uart_valid <= 1;
                    uart_bit_count <= 0;
                    $write("%c", uart_shift_reg[8:1]); // Print character
                    $fflush();
                end
            end else begin
                uart_baud_counter <= uart_baud_counter - 1;
            end
        end
    end
    
    // Test result checking
    localparam TEST_RESULT_BASE = 32'h3F00;
    localparam TEST_STATUS_ADDR = 32'h3FFC;
    localparam TEST_MAGIC_DONE  = 32'hDEADBEEF;
    int test_passed_count = 0;
    int test_failed_count = 0;
    int test_total_count = 0;
    
    // Main test procedure
    // With --no-timing and C++ driving clock, testbench is simplified
    // Test checking will be done in C++
    // VCD dumping handled in C++ sim_main.cpp
    initial begin
        $display("=== Starting RISC-V SoC Simulation ===");
        $display("Testbench initialized, clock driven from C++");

        #1; // Wait a moment for Verilator to initialize and load memory
        $display("--- Initial Memory Content (First 16 Words) ---");
        for (int i=0; i<16; i++) begin
            $display("MEM[0x%h] = 0x%h", i*4, dut.u_ram.memory[i]);
        end
        $display("-------------------------------------------------");
    end
    
    // Timeout handled in C++ sim_main.cpp
    
    // Monitor CPU state and memory/UART writes
    always @(posedge clk) begin
        if (rst_n) begin            
            // Monitor RAM writes to test result area
            if (dut.u_simple_bus.ram_req && dut.u_simple_bus.ram_we) begin
                if (dut.u_simple_bus.ram_addr >= 32'h3F00 && dut.u_simple_bus.ram_addr < 32'h4000) begin
                    $display("[%0t] RAM WRITE: addr=0x%h data=0x%h (PC=0x%h)", 
                             $time, dut.u_simple_bus.ram_addr, 
                             dut.u_simple_bus.ram_wdata,
                             dut.u_cpu_core.pc);
                end
            end
            
            // Monitor UART accesses
            if (dut.u_simple_bus.uart_req) begin
                if (dut.u_simple_bus.uart_we) begin
                    $display("[%0t] UART WRITE: addr=0x%h data=0x%02h '%c' (PC=0x%h)", 
                             $time, dut.u_simple_bus.uart_addr, 
                             dut.u_simple_bus.uart_wdata[7:0],
                             dut.u_simple_bus.uart_wdata[7:0],
                             dut.u_cpu_core.pc);
                end
            end
            

        end
    end

endmodule
