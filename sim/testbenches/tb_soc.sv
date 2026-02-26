`timescale 1ns / 1ps

module tb_soc;
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // UART interface
    logic uart_tx;
    
    // Instantiate the SoC with test program loaded
    riscv_soc #(
        .MEM_INIT_FILE("build/hello.hex")
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // Clock generation: 50MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
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
    
    // Main test procedure
    initial begin
        $dumpfile("sim/waveforms/tb_soc.vcd");
        $dumpvars(0, tb_soc);
        
        // Display memory contents for debugging
        $display("=== Starting RISC-V SoC Simulation ===");
        $display("Time: %0t", $time);
        
        // Reset sequence (active low)
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        $display("Reset released at time %0t", $time);
        
        // Let it run for a while to print message
        $display("Waiting for UART output...");
        
        // Trace execution through print_loop iterations
        repeat(20) @(posedge clk);
        $display("\n=== Tracing print_loop execution ===");
        $display("Expected flow: 0x14->0x18->0x1C->0x20->0x24->0x28->0x2C->0x30->0x14 (loop)");
        for (int i = 0; i < 300; i++) begin
            @(posedge clk);
            // Track all state transitions in the print_loop region
            if (dut.u_cpu_core.pc >= 32'h14 && dut.u_cpu_core.pc <= 32'h34) begin
                if (dut.u_cpu_core.state == 1) begin // FETCH
                    $display("[%0t] FETCH     PC=0x%02h | a0=0x%h t0=0x%h t1=0x%h", 
                             $time, dut.u_cpu_core.pc,
                             dut.u_cpu_core.u_register_file.registers[10],
                             dut.u_cpu_core.u_register_file.registers[5],
                             dut.u_cpu_core.u_register_file.registers[6]);
                end
                else if (dut.u_cpu_core.state == 4) begin // EXECUTE
                    $display("[%0t] EXECUTE   PC=0x%02h | alu_result=0x%h branch_taken=%b is_jal=%b is_jalr=%b", 
                             $time, dut.u_cpu_core.pc, dut.u_cpu_core.alu_result,
                             dut.u_cpu_core.branch_taken, dut.u_cpu_core.is_jal, dut.u_cpu_core.is_jalr);
                end
                else if (dut.u_cpu_core.state == 7) begin // WRITEBACK
                    $display("[%0t] WRITEBACK PC=0x%02h | rd=x%0d we=%b data=0x%h next_pc=0x%h", 
                             $time, dut.u_cpu_core.pc, dut.u_cpu_core.rd,
                             dut.u_cpu_core.rf_rd_we, dut.u_cpu_core.rf_rd_data, dut.u_cpu_core.next_pc);
                end
            end
        end
        $display("=== End trace ===\n");
        
        repeat(2000000) @(posedge clk);
        
        // Check if we got any UART output
        $display("\n=== Simulation Complete ===");
        $display("Final PC: 0x%08h", dut.u_cpu_core.pc);
        $display("Total cycles: %0d", $time / 20);
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100_000_000; // 100ms timeout
        $display("\n=== TIMEOUT ===");
        $display("Simulation timed out at %0t", $time);
        $finish;
    end
    
    // Monitor CPU state and UART writes
    always @(posedge clk) begin
        if (rst_n) begin            
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
            
            // Monitor key register writes to a0 (x10)
            if (dut.u_cpu_core.rf_rd_we && dut.u_cpu_core.rf_rd_addr == 10) begin
                $display("[%0t] *** REG x10 (a0) <= 0x%h (PC=0x%h)", 
                         $time, dut.u_cpu_core.rf_rd_data, dut.u_cpu_core.pc);
            end
        end
    end

endmodule
