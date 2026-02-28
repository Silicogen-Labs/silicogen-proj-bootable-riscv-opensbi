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
    
    // One-shot probe: when PC = 0x181c (fw_boot_hart magic bne), print a0 vs a1
    logic fwboot_probed;
    initial fwboot_probed = 0;
    always @(posedge clk) begin
        if (rst_n && !fwboot_probed && dut.u_cpu_core.pc == 32'h181c) begin
            fwboot_probed <= 1;
            $display("[PROBE@181c] a0=0x%h a1=0x%h a2=0x%h (magic check: a0 should==0x4942534f)",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12]);
        end
    end

    // Probe version check: 0x1828 blt a1,a0 -> hang if version>2
    logic probe1828;
    initial probe1828 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1828 && dut.u_cpu_core.pc == 32'h1828) begin
            probe1828 <= 1;
            $display("[PROBE@1828] a0(version)=0x%h a1=0x%h (blt: hang if version>2)",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11]);
        end
    end

    // Probe 0x1830: blt a0,a1 -> if version<2 goto 0x183c else fall through to lw boot_hart
    logic probe1830;
    initial probe1830 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1830 && dut.u_cpu_core.pc == 32'h1830) begin
            probe1830 <= 1;
            $display("[PROBE@1830] a0(version)=0x%h a1=0x%h (blt: if version<2 skip boot_hart load)",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11]);
        end
    end

    // Probe 0x1834: lw a0,20(a2) -> load boot_hart field
    logic probe1834;
    initial probe1834 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1834 && dut.u_cpu_core.pc == 32'h1834) begin
            probe1834 <= 1;
            $display("[PROBE@1834] a2=0x%h -> loading boot_hart from offset 20",
                     dut.u_cpu_core.u_register_file.registers[12]);
        end
    end

    // Probe 0x1838: ret from fw_boot_hart (should return boot_hart in a0)
    logic probe1838;
    initial probe1838 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1838 && dut.u_cpu_core.pc == 32'h1838) begin
            probe1838 <= 1;
            $display("[PROBE@1838] a0(boot_hart)=0x%h ra=0x%h (ret from fw_boot_hart)",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[1]);
        end
    end

    // Probe return site 0x100c: after jal fw_boot_hart returns
    logic probe100c;
    initial probe100c = 0;
    always @(posedge clk) begin
        if (rst_n && !probe100c && dut.u_cpu_core.pc == 32'h100c) begin
            probe100c <= 1;
            $display("[PROBE@100c] a0(boot_hart_result)=0x%h (back at _start after fw_boot_hart)",
                     dut.u_cpu_core.u_register_file.registers[10]);
            $display("[PROBE@100c] s0(hart_id)=0x%h s1(fdt_addr)=0x%h s2(opaque)=0x%h",
                     dut.u_cpu_core.u_register_file.registers[8],
                     dut.u_cpu_core.u_register_file.registers[9],
                     dut.u_cpu_core.u_register_file.registers[18]);
        end
    end

    // Probe 0x1024: beq a6,a7,_try_lottery
    logic probe1024;
    initial probe1024 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1024 && dut.u_cpu_core.pc == 32'h1024) begin
            probe1024 <= 1;
            $display("[PROBE@1024] a6(boot_hart)=0x%h a7=-1=0x%h (beq: if -1 goto lottery)",
                     dut.u_cpu_core.u_register_file.registers[16],
                     dut.u_cpu_core.u_register_file.registers[17]);
        end
    end

    // Probe _start_hang entry: 0x1458
    logic probe1458;
    initial probe1458 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1458 && dut.u_cpu_core.pc == 32'h1458) begin
            probe1458 <= 1;
            $display("[PROBE@1458] _start_hang reached! a0=0x%h a6=0x%h ra=0x%h pc_prev via mepc=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[16],
                     dut.u_cpu_core.u_register_file.registers[1],
                     dut.u_cpu_core.mepc_out);
        end
    end

    // Watch every write to x1 (ra) -- fires max 4 times to avoid flooding
    int ra_write_count = 0;
    always @(posedge clk) begin
        if (rst_n && ra_write_count < 4) begin
            if (dut.u_cpu_core.rf_rd_we &&
                dut.u_cpu_core.rf_rd_addr == 5'd1) begin
                ra_write_count <= ra_write_count + 1;
                $display("[RA_WRITE #%0d] PC=0x%h  ra <= 0x%h  (instr=0x%h)",
                         ra_write_count,
                         dut.u_cpu_core.pc,
                         dut.u_cpu_core.rf_rd_data,
                         dut.u_cpu_core.instruction);
            end
        end
    end

    // Probe 0x1038: amoswap.w a6,a7,(a6) — lottery lock acquisition
    logic probe1038;
    initial probe1038 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1038 && dut.u_cpu_core.pc == 32'h1038) begin
            probe1038 <= 1;
            $display("[PROBE@1038] AMOSWAP: addr(a6)=0x%h  a7(new_val)=0x%h  mem[0x41000]=0x%h",
                     dut.u_cpu_core.u_register_file.registers[16],
                     dut.u_cpu_core.u_register_file.registers[17],
                     dut.u_ram.memory[32'h41000 >> 2]);
        end
    end

    // Probe 0x103c: bnez a16, _wait_for_boot_hart — check result of amoswap
    logic probe103c;
    initial probe103c = 0;
    always @(posedge clk) begin
        if (rst_n && !probe103c && dut.u_cpu_core.pc == 32'h103c) begin
            probe103c <= 1;
            $display("[PROBE@103c] POST-AMOSWAP: a6(old_val)=0x%h  mem[0x41000]=0x%h  (0==win lottery)",
                     dut.u_cpu_core.u_register_file.registers[16],
                     dut.u_ram.memory[32'h41000 >> 2]);
        end
    end

    // Probe 0x1040: first instruction past lottery win
    logic probe1040;
    initial probe1040 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1040 && dut.u_cpu_core.pc == 32'h1040) begin
            probe1040 <= 1;
            $display("[PROBE@1040] WON LOTTERY - proceeding with boot");
        end
    end

    // Monitor CPU state and memory/UART writes
    // One-shot memory content check after reset
    logic mem_checked;
    initial mem_checked = 0;
    always @(posedge clk) begin
        if (rst_n && !mem_checked) begin
            mem_checked <= 1;
            $display("[MEMCHECK] mem[0x00]=0x%h mem[0x04]=0x%h mem[0x08]=0x%h mem[0x0c]=0x%h",
                     dut.u_ram.memory[0], dut.u_ram.memory[1],
                     dut.u_ram.memory[2], dut.u_ram.memory[3]);
            $display("[MEMCHECK] mem[0x10]=0x%h mem[0x14]=0x%h mem[0x18]=0x%h mem[0x1c]=0x%h",
                     dut.u_ram.memory[4], dut.u_ram.memory[5],
                     dut.u_ram.memory[6], dut.u_ram.memory[7]);
            $display("[MEMCHECK] mem[0x1000/4=0x400]=0x%h  (OpenSBI entry)",
                     dut.u_ram.memory[32'h400]);
        end
    end

    // Probe sbi_init entry (ELF 0x5d64 + 0x1000 = 0x6d64)
    logic probe_sbiinit;
    initial probe_sbiinit = 0;
    always @(posedge clk) begin
        if (rst_n && !probe_sbiinit && dut.u_cpu_core.pc == 32'h6d64) begin
            probe_sbiinit <= 1;
            $display("[PROBE@6d64] sbi_init entered: a0=0x%h sp=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[2]);
        end
    end

    // Probe 0x160ac - sbi_ecall_cppc_register_extensions loop site
    logic probe160ac;
    initial probe160ac = 0;
    always @(posedge clk) begin
        if (rst_n && !probe160ac && dut.u_cpu_core.pc == 32'h160ac) begin
            probe160ac <= 1;
            $display("[PROBE@160ac] sbi_ecall_cppc: a0=0x%h a5=0x%h sp=0x%h ra=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[15],
                     dut.u_cpu_core.u_register_file.registers[2],
                     dut.u_cpu_core.u_register_file.registers[1]);
        end
    end

    // Probe mtvec final set to _start_hang (ELF 0x110 + 0x1000 = 0x1110)
    logic probe_mtvec_hang;
    initial probe_mtvec_hang = 0;
    always @(posedge clk) begin
        if (rst_n && !probe_mtvec_hang && dut.u_cpu_core.pc == 32'h1110) begin
            probe_mtvec_hang <= 1;
            $display("[PROBE@1110] mtvec <- _start_hang: mtvec=0x%h s4=0x%h",
                     dut.u_cpu_core.mtvec_base,
                     dut.u_cpu_core.u_register_file.registers[20]); // s4
        end
    end

    // Trap monitor - print all traps (up to 20)
    int trap_count = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            // Monitor CPU traps (trap_taken is a 1-cycle pulse when entering STATE_TRAP)
            if (dut.u_cpu_core.trap_taken && trap_count < 20) begin
                trap_count <= trap_count + 1;
                $display("[%0t] TRAP #%0d: pc=0x%h cause=%0d(%s) mtval=0x%h mtvec=0x%h sp=0x%h",
                         $time, trap_count,
                         dut.u_cpu_core.trap_pc_latched,
                         dut.u_cpu_core.trap_cause_latched,
                         dut.u_cpu_core.is_interrupt_latched ? "IRQ" : "EXC",
                          dut.u_cpu_core.trap_value_latched,
                         dut.u_cpu_core.mtvec_base,
                         dut.u_cpu_core.u_register_file.registers[2]);
            end

            // Monitor RAM writes to test result area
            if (dut.u_simple_bus.ram_req && dut.u_simple_bus.ram_we) begin
                if (dut.u_simple_bus.ram_addr >= 32'h3F00 && dut.u_simple_bus.ram_addr < 32'h4000) begin
                    $display("[%0t] RAM WRITE: addr=0x%h data=0x%h (PC=0x%h)", 
                             $time, dut.u_simple_bus.ram_addr, 
                             dut.u_simple_bus.ram_wdata,
                             dut.u_cpu_core.pc);
                end
            end
            
            // Monitor UART accesses (DISABLED - using detailed UART probes below)
            // if (dut.u_simple_bus.uart_req) begin
            //     if (dut.u_simple_bus.uart_we) begin
            //         $display("[%0t] UART WRITE: addr=0x%h data=0x%02h '%c' (PC=0x%h)", 
            //                  $time, dut.u_simple_bus.uart_addr, 
            //                  dut.u_simple_bus.uart_wdata[7:0],
            //                  dut.u_simple_bus.uart_wdata[7:0],
            //                  dut.u_cpu_core.pc);
            //     end
            // end
            

        end
    end

    // --- Probes for sbi_init console_init call chain ---

    // fw_jump: 0x6d28: beq s2, zero -- if s2==0 skip console path entirely
    logic probe6d28;
    initial probe6d28 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe6d28 && dut.u_cpu_core.pc == 32'h6d28) begin
            probe6d28 <= 1;
            $display("[PROBE@6d28] s2(platform_addr)=0x%h s3(hartid)=0x%h (beq s2,zero->skip)",
                     dut.u_cpu_core.u_register_file.registers[18],
                     dut.u_cpu_core.u_register_file.registers[19]);
        end
    end

    // fw_jump: 0x6d2c: lw a5, 96(s2) -- load platform_ops pointer
    logic probe6d2c;
    initial probe6d2c = 0;
    always @(posedge clk) begin
        if (rst_n && !probe6d2c && dut.u_cpu_core.pc == 32'h6d2c) begin
            probe6d2c <= 1;
            $display("[PROBE@6d2c] s2(platform)=0x%h  mem[s2+96]=0x%h  (loading ops ptr)",
                     dut.u_cpu_core.u_register_file.registers[18],
                     dut.u_ram.memory[(dut.u_cpu_core.u_register_file.registers[18] + 96) >> 2]);
        end
    end

    // fw_jump: 0x6d34: beq a5, zero -- NULL-check before calling console_init
    logic probe6d34;
    initial probe6d34 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe6d34 && dut.u_cpu_core.pc == 32'h6d34) begin
            probe6d34 <= 1;
            $display("[PROBE@6d34] a5(console_init_ptr)=0x%h  (0=NULL->skip, nonzero=call)",
                     dut.u_cpu_core.u_register_file.registers[15]);
        end
    end

    // fw_jump: 0x6d38: jalr ra, 0(a5) -- call console_init (a5 is non-zero!)
    logic probe6d38;
    initial probe6d38 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe6d38 && dut.u_cpu_core.pc == 32'h6d38) begin
            probe6d38 <= 1;
            $display("[PROBE@6d38] CALLING console_init: a5(fn_ptr)=0x%h  a0=0x%h  s3(hartid)=0x%h",
                     dut.u_cpu_core.u_register_file.registers[15],
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[19]);
        end
    end

    // 0x6dd4: jalr ra,0(a5) -- the actual call site (trap fires here)
    logic probe6dd4;
    initial probe6dd4 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe6dd4 && dut.u_cpu_core.pc == 32'h6dd4) begin
            probe6dd4 <= 1;
            $display("[PROBE@6dd4] JALR: a5(fn_ptr)=0x%h  ra(will_be)=0x6dd8  state=%0d",
                     dut.u_cpu_core.u_register_file.registers[15],
                     dut.u_cpu_core.state);
        end
    end

    // Probe 0x1018: Restore a1 from s1 (FDT address)
    logic probe1018;
    initial probe1018 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1018 && dut.u_cpu_core.pc == 32'h1018) begin
            probe1018 <= 1;
            $display("[PROBE@1018] Before restore: a1=0x%h s1(fdt)=0x%h",
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[9]);
        end
    end
    
    // Probe 0x116c: Call to fw_platform_init
    logic probe116c;
    initial probe116c = 0;
    always @(posedge clk) begin
        if (rst_n && !probe116c && dut.u_cpu_core.pc == 32'h116c) begin
            probe116c <= 1;
            $display("[PROBE@116c] Calling fw_platform_init: a0(hart)=0x%h a1(fdt)=0x%h a2=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12]);
        end
    end
    
    // Probe 0x1aec: fw_platform_init entry
    logic probe1aec;
    initial probe1aec = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1aec && dut.u_cpu_core.pc == 32'h1aec) begin
            probe1aec <= 1;
            $display("[PROBE@1aec] fw_platform_init ENTRY: a0(hart)=0x%h a1(fdt)=0x%h a2=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12]);
        end
    end
    
    // Probe 0x1170: Return from fw_platform_init
    logic probe1170;
    initial probe1170 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1170 && dut.u_cpu_core.pc == 32'h1170) begin
            probe1170 <= 1;
            $display("[PROBE@1170] RETURN from fw_platform_init: a0(return_val)=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10]);
        end
    end
    
    // Probe 0x101c: After restore, check a1
    logic probe101c;
    initial probe101c = 0;
    always @(posedge clk) begin
        if (rst_n && !probe101c && dut.u_cpu_core.pc == 32'h101c) begin
            probe101c <= 1;
            $display("[PROBE@101c] After restore: a1=0x%h (should be 0x003f0000)",
                     dut.u_cpu_core.u_register_file.registers[11]);
        end
    end

    // Probe 0x1418: Call to sbi_init from fw_jump  
    logic probe1418;
    initial probe1418 = 0;
    always @(posedge clk) begin
        if (rst_n && !probe1418 && dut.u_cpu_core.pc == 32'h1418) begin
            probe1418 <= 1;
            $display("[PROBE@1418] Calling sbi_init: a0(scratch_ptr)=0x%h a1(fdt)=0x%h",
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11]);
            if (dut.u_cpu_core.u_register_file.registers[10] != 0) begin
                $display("[PROBE@1418] scratch[20]=0x%h (FDT from fw_next_arg1)",
                        dut.u_ram.memory[(dut.u_cpu_core.u_register_file.registers[10] + 20) >> 2]);
            end
        end
    end
    
    // Probe 0x6e80: Loading platform operations in sbi_init
    logic probe6e80;
    integer probe6e80_count;
    initial begin
        probe6e80 = 0;
        probe6e80_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h6e80 && probe6e80_count < 3) begin
            $display("[SBI_INIT_OPS #%0d] Loading platform ops: s2(platform)=0x%h offset=96",
                     probe6e80_count,
                     dut.u_cpu_core.u_register_file.registers[18]);
            if (dut.u_cpu_core.u_register_file.registers[18] != 0) begin
                $display("[SBI_INIT_OPS #%0d]  platform_ops_ptr at s2+96 = 0x%h",
                         probe6e80_count,
                         dut.u_ram.memory[(dut.u_cpu_core.u_register_file.registers[18] + 96) >> 2]);
            end
            probe6e80_count <= probe6e80_count + 1;
        end
    end
    
    // Probe 0x6e8c: About to call platform warm_init (first callback)
    logic probe6e8c;
    integer probe6e8c_count;
    initial begin
        probe6e8c = 0;
        probe6e8c_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h6e8c && probe6e8c_count < 3) begin
            $display("[WARM_INIT_CALL #%0d] Calling platform warm_init: a0(hartid)=0x%h a5(func_ptr)=0x%h",
                     probe6e8c_count,
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[15]);
            probe6e8c_count <= probe6e8c_count + 1;
        end
    end
    
    // Probe 0x6ee0: Loading early_init callback
    logic probe6ee0;
    integer probe6ee0_count;
    initial begin
        probe6ee0 = 0;
        probe6ee0_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h6ee0 && probe6ee0_count < 3) begin
            $display("[EARLY_INIT_LOAD #%0d] Loading early_init callback: s2(platform)=0x%h",
                     probe6ee0_count,
                     dut.u_cpu_core.u_register_file.registers[18]);
            if (dut.u_cpu_core.u_register_file.registers[18] != 0) begin
                logic [31:0] ops_addr;
                ops_addr = dut.u_ram.memory[(dut.u_cpu_core.u_register_file.registers[18] + 96) >> 2];
                $display("[EARLY_INIT_LOAD #%0d]  platform_ops at 0x%h", probe6ee0_count, ops_addr);
                $display("[EARLY_INIT_LOAD #%0d]   ops[0] cold_boot_allowed = 0x%h", probe6ee0_count, dut.u_ram.memory[(ops_addr + 0) >> 2]);
                $display("[EARLY_INIT_LOAD #%0d]   ops[4] single_fw_region = 0x%h", probe6ee0_count, dut.u_ram.memory[(ops_addr + 4) >> 2]);
                $display("[EARLY_INIT_LOAD #%0d]   ops[8] nascent_init = 0x%h", probe6ee0_count, dut.u_ram.memory[(ops_addr + 8) >> 2]);
                $display("[EARLY_INIT_LOAD #%0d]   ops[12] early_init = 0x%h", probe6ee0_count, dut.u_ram.memory[(ops_addr + 12) >> 2]);
                $display("[EARLY_INIT_LOAD #%0d]   ops[16] final_init = 0x%h", probe6ee0_count, dut.u_ram.memory[(ops_addr + 16) >> 2]);
            end
            probe6ee0_count <= probe6ee0_count + 1;
        end
    end

    // 0x1b6d8: __qdivrem entry - 64-bit division routine
    logic probe1b6d8;
    logic [31:0] qdivrem_call_count;
    logic [31:0] qdivrem_return_count;
    logic [31:0] hw_div_count;
    initial begin
        probe1b6d8 = 0;
        qdivrem_call_count = 0;
        qdivrem_return_count = 0;
        hw_div_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h1b6d8) begin
            if (!probe1b6d8) begin
                probe1b6d8 <= 1;
                $display("[PROBE@1b6d8] __qdivrem ENTRY #%0d: a0=0x%h a1=0x%h a2=0x%h a3=0x%h (64-bit div)",
                         qdivrem_call_count,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_cpu_core.u_register_file.registers[11],
                         dut.u_cpu_core.u_register_file.registers[12],
                         dut.u_cpu_core.u_register_file.registers[13]);
            end
            qdivrem_call_count <= qdivrem_call_count + 1;
            if (qdivrem_call_count % 10000 == 0 && qdivrem_call_count > 0) begin
                $display("[DIV_LOOP] __qdivrem called %0d times - may be stuck!", qdivrem_call_count);
            end
        end
        // Check for __qdivrem return
        if (rst_n && dut.u_cpu_core.pc == 32'h1b7bc) begin
            qdivrem_return_count <= qdivrem_return_count + 1;
            if (qdivrem_return_count < 5 || qdivrem_return_count % 10000 == 0) begin
                $display("[DIV_RETURN] __qdivrem returning (count=%0d) a0=0x%h a1=0x%h",
                         qdivrem_return_count,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_cpu_core.u_register_file.registers[11]);
            end
        end
        // Monitor hardware DIV/DIVU instructions
        if (rst_n && dut.u_cpu_core.u_muldiv.start && hw_div_count < 20) begin
            if (dut.u_cpu_core.u_muldiv.muldiv_op == 3'b100 ||   // DIV
                dut.u_cpu_core.u_muldiv.muldiv_op == 3'b101) begin // DIVU
                hw_div_count <= hw_div_count + 1;
                $display("[HW_DIV #%0d] PC=0x%h op=%s operand_a=0x%h operand_b=0x%h (expected: a/b=0x%h) state=%0d quot_before=0x%h",
                         hw_div_count,
                         dut.u_cpu_core.pc,
                         (dut.u_cpu_core.u_muldiv.muldiv_op == 3'b100) ? "DIV" : "DIVU",
                         dut.u_cpu_core.u_muldiv.operand_a,
                         dut.u_cpu_core.u_muldiv.operand_b,
                         dut.u_cpu_core.u_muldiv.operand_a / dut.u_cpu_core.u_muldiv.operand_b,
                         dut.u_cpu_core.u_muldiv.state,
                         dut.u_cpu_core.u_muldiv.div_quotient);
            end
        end
        // Monitor hardware DIV/DIVU results
        if (rst_n && dut.u_cpu_core.u_muldiv.done && hw_div_count <= 20) begin
            if (dut.u_cpu_core.u_muldiv.operation == 3'b100 ||   // DIV
                dut.u_cpu_core.u_muldiv.operation == 3'b101) begin // DIVU
                $display("[HW_DIV_RESULT] result=0x%h (cycle_count=%0d)",
                         dut.u_cpu_core.u_muldiv.result,
                         dut.u_cpu_core.u_muldiv.cycle_count);
            end
        end
    end

    // --- spin_lock probe (NEW ADDRESSES for current build) ---
    // spin_lock entry at 0x16108, spin loop at 0x16128-0x16138
    integer spinlock_entry_count;
    initial spinlock_entry_count = 0;
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h16108) begin
            if (spinlock_entry_count < 50) begin
                $display("[SPINLOCK] Entry #%0d at 0x16108: a0(lock_addr)=0x%h  ra=0x%h",
                         spinlock_entry_count,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_cpu_core.u_register_file.registers[1]);
                spinlock_entry_count <= spinlock_entry_count + 1;
            end
        end
    end
    
    // Probe the spin loop itself at 0x16128
    integer spinlock_loop_count;
    initial spinlock_loop_count = 0;
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h16128) begin
            if (spinlock_loop_count < 100) begin
                $display("[SPINLOCK_LOOP] #%0d at 0x16128: a0(lock_addr)=0x%h a1=0x%h a2(expected)=0x%h a3(current)=0x%h a4(mask)=0x%h",
                         spinlock_loop_count,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_cpu_core.u_register_file.registers[11],
                         dut.u_cpu_core.u_register_file.registers[12],
                         dut.u_cpu_core.u_register_file.registers[13],
                         dut.u_cpu_core.u_register_file.registers[14]);
                spinlock_loop_count <= spinlock_loop_count + 1;
            end
        end
    end

    // amoadd.w.aqrl at 0x1611c -- show ticket state before atomic operation
    logic probe_amoadd_entry;
    integer amoadd_entry_count;
    initial begin
        probe_amoadd_entry = 0;
        amoadd_entry_count = 0;
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h1611c) begin
            if (amoadd_entry_count < 20) begin
                $display("[AMOADD] Entry #%0d at 0x1611c: lock_addr(a0)=0x%h  a5(add_val)=0x%h  state=%0d",
                         amoadd_entry_count,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_cpu_core.u_register_file.registers[15],
                         dut.u_cpu_core.state);
                amoadd_entry_count <= amoadd_entry_count + 1;
            end
        end
        
        // Track AMO execution through states
        if (rst_n && amoadd_entry_count > 0 && amoadd_entry_count <= 20) begin
            if (dut.u_cpu_core.state == 5 && dut.u_cpu_core.is_atomic) begin  // STATE_MEMORY
                $display("[AMOADD_STATE] STATE_MEMORY: Reading from addr=0x%h", 
                         dut.u_cpu_core.u_register_file.registers[10]);
            end else if (dut.u_cpu_core.state == 6 && dut.u_cpu_core.is_atomic) begin  // STATE_MEMORY_WAIT
                if (dut.u_simple_bus.dbus_ready) begin
                    $display("[AMOADD_STATE] STATE_MEMORY_WAIT: Read complete, old_value=0x%h, rs2=0x%h, new_value=0x%h",
                             dut.u_simple_bus.dbus_rdata,
                             dut.u_cpu_core.u_register_file.registers[15],
                             dut.u_simple_bus.dbus_rdata + dut.u_cpu_core.u_register_file.registers[15]);
                end
            end else if (dut.u_cpu_core.state == 7) begin  // STATE_AMO_WRITE
                $display("[AMOADD_STATE] STATE_AMO_WRITE: Writing back value=0x%h to addr=0x%h wstrb=0x%h funct3=0x%h",
                         dut.u_cpu_core.amo_write_data,
                         dut.u_cpu_core.u_register_file.registers[10],
                         dut.u_simple_bus.dbus_wstrb,
                         dut.u_cpu_core.funct3);
            end else if (dut.u_cpu_core.state == 8) begin  // STATE_AMO_WRITE_WAIT
                if (dut.u_simple_bus.dbus_ready) begin
                    $display("[AMOADD_STATE] STATE_AMO_WRITE_WAIT: Write complete, wdata=0x%h wstrb=0x%h",
                             dut.u_simple_bus.dbus_wdata,
                             dut.u_simple_bus.dbus_wstrb);
                end
            end
        end
    end

    // Check a3 value right after AMOADD completes (at 0x16120 - first instruction after amoadd)
    logic probe_after_amoadd;
    integer amoadd_complete_count;
    initial begin
        probe_after_amoadd = 0;
        amoadd_complete_count = 0;
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h16120) begin
            if (amoadd_complete_count < 20) begin
                $display("[AMOADD_RESULT] After AMOADD at 0x16120: a3(old_lock_value)=0x%h  upper16=0x%h  lower16=0x%h",
                         dut.u_cpu_core.u_register_file.registers[13],
                         dut.u_cpu_core.u_register_file.registers[13] >> 16,
                         dut.u_cpu_core.u_register_file.registers[13] & 32'hffff);
                amoadd_complete_count <= amoadd_complete_count + 1;
            end
        end
    end
    
    // ========================================
    // CRITICAL CONSOLE DEBUG PROBES
    // ========================================
    
    // Probe bootble_early_init entry at 0x11b58
    logic probe_bootble_early_init;
    integer bootble_early_init_count;
    initial begin
        probe_bootble_early_init = 0;
        bootble_early_init_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h11b58 && bootble_early_init_count < 5) begin
            $display("[BOOTBLE_EARLY_INIT #%0d] *** ENTERED bootble_early_init! a0(cold_boot)=0x%h PC=0x11b58 ***",
                     bootble_early_init_count,
                     dut.u_cpu_core.u_register_file.registers[10]);
            bootble_early_init_count <= bootble_early_init_count + 1;
        end
    end
    
    // Probe uart8250_init entry at 0x1c0fc (NEW ADDRESS from current build)
    logic probe_uart8250_new;
    integer uart8250_new_count;
    initial begin
        probe_uart8250_new = 0;
        uart8250_new_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h1c0fc && uart8250_new_count < 5) begin
            $display("[UART8250_INIT_NEW #%0d] *** ENTERED uart8250_init! a0(base)=0x%h a1(freq)=0x%h a2(baud)=0x%h a3(reg_shift)=0x%h a4(reg_width)=0x%h ***",
                     uart8250_new_count,
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12],
                     dut.u_cpu_core.u_register_file.registers[13],
                     dut.u_cpu_core.u_register_file.registers[14]);
            uart8250_new_count <= uart8250_new_count + 1;
        end
    end
    
    // Probe sbi_console_set_device entry at 0x2a18
    logic probe_console_set;
    integer console_set_count;
    initial begin
        probe_console_set = 0;
        console_set_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h2a18 && console_set_count < 5) begin
            $display("[SBI_CONSOLE_SET #%0d] *** ENTERED sbi_console_set_device! a0(dev_ptr)=0x%h ***",
                     console_set_count,
                     dut.u_cpu_core.u_register_file.registers[10]);
            console_set_count <= console_set_count + 1;
        end
    end
    
    // Probe memory write to platform_ops.early_init at 0x41524
    logic probe_platform_ops_write;
    integer platform_ops_write_count;
    initial begin
        probe_platform_ops_write = 0;
        platform_ops_write_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr >= 32'h00041518 && 
            dut.u_simple_bus.dbus_addr <= 32'h00041530 && 
            platform_ops_write_count < 20) begin
            $display("[PLATFORM_OPS_WRITE #%0d] Writing to platform_ops! addr=0x%h data=0x%h offset=%0d",
                     platform_ops_write_count,
                     dut.u_simple_bus.dbus_addr,
                     dut.u_simple_bus.dbus_wdata,
                     dut.u_simple_bus.dbus_addr - 32'h00041518);
            platform_ops_write_count <= platform_ops_write_count + 1;
        end
    end
    
    // Probe memory READ from platform_ops.early_init area
    logic probe_platform_ops_read;
    integer platform_ops_read_count;
    initial begin
        probe_platform_ops_read = 0;
        platform_ops_read_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && !dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr >= 32'h00041518 && 
            dut.u_simple_bus.dbus_addr <= 32'h00041530 && 
            platform_ops_read_count < 20) begin
            $display("[PLATFORM_OPS_READ #%0d] Reading from platform_ops! addr=0x%h offset=%0d",
                     platform_ops_read_count,
                     dut.u_simple_bus.dbus_addr,
                     dut.u_simple_bus.dbus_addr - 32'h00041518);
            platform_ops_read_count <= platform_ops_read_count + 1;
        end
    end
    
    // ========================================
    // LOCK MEMORY ACCESS TRACKING
    // ========================================
    
    // Track all writes to lock address 0x00041100
    integer lock_write_count;
    initial lock_write_count = 0;
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr == 32'h00041100 && dut.u_simple_bus.dbus_ready &&
            lock_write_count < 30) begin
            $display("[LOCK_WRITE #%0d] addr=0x00041100 wdata=0x%h wstrb=0x%h PC=0x%h",
                     lock_write_count,
                     dut.u_simple_bus.dbus_wdata,
                     dut.u_simple_bus.dbus_wstrb,
                     dut.u_cpu_core.pc);
            lock_write_count <= lock_write_count + 1;
        end
    end
    
    // Track all reads from lock address 0x00041100
    integer lock_read_count;
    initial lock_read_count = 0;
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && !dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr == 32'h00041100 && dut.u_simple_bus.dbus_ready &&
            lock_read_count < 30) begin
            $display("[LOCK_READ #%0d] addr=0x00041100 rdata=0x%h PC=0x%h",
                     lock_read_count,
                     dut.u_simple_bus.dbus_rdata,
                     dut.u_cpu_core.pc);
            lock_read_count <= lock_read_count + 1;
        end
    end
    
    // ========================================
    // UART DETAILED DEBUGGING
    // ========================================
    
    // Track UART THR writes (character transmissions) - Write to file
    integer uart_write_count;
    integer uart_file;
    integer uart_debug_file;
    initial begin
        uart_write_count = 0;
        uart_file = $fopen("/tmp/uart_output.txt", "w");
        uart_debug_file = $fopen("/tmp/uart_debug.txt", "w");
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr == 32'h10000000 && dut.u_simple_bus.dbus_ready &&
            1) begin
            // Debug: log full transaction details INCLUDING PC
            $fwrite(uart_debug_file, "[%0d] PC=0x%h addr=0x%h wdata=0x%08x wstrb=0x%x byte0=0x%02x\n",
                    uart_write_count,
                    dut.u_cpu_core.pc,
                    dut.u_simple_bus.dbus_addr,
                    dut.u_simple_bus.dbus_wdata,
                    dut.u_simple_bus.dbus_wstrb,
                    dut.u_simple_bus.dbus_wdata[7:0]);
            $fflush(uart_debug_file);
            
            // Write character to file (only byte 0)
            $fwrite(uart_file, "%c", dut.u_simple_bus.dbus_wdata[7:0]);
            $fflush(uart_file);
            
            // Print character to stdout immediately (bus snoop, not serial decode)
            $write("%c", dut.u_simple_bus.dbus_wdata[7:0]);
            $fflush();
            
            uart_write_count <= uart_write_count + 1;
        end
    end
    
    // Track UART LSR reads (status polling) - DISABLED due to display interleaving
    // integer uart_lsr_read_count;
    // initial uart_lsr_read_count = 0;
    // always @(posedge clk) begin
    //     if (rst_n && dut.u_simple_bus.dbus_req && !dut.u_simple_bus.dbus_we && 
    //         dut.u_simple_bus.dbus_addr == 32'h10000005 && dut.u_simple_bus.dbus_ready &&
    //         uart_lsr_read_count < 200) begin
    //         $display("[UART_LSR_READ #%0d] time=%0dns PC=0x%h LSR=0x%02x (THRE=%d TEMT=%d)",
    //                  uart_lsr_read_count,
    //                  $time,
    //                  dut.u_cpu_core.pc,
    //                  dut.u_simple_bus.dbus_rdata[7:0],
    //                  dut.u_simple_bus.dbus_rdata[5],
    //                  dut.u_simple_bus.dbus_rdata[6]);
    //         uart_lsr_read_count <= uart_lsr_read_count + 1;
    //     end
    // end
    
    // Track string loads in nputs function - PC=0x1990 is "lbu a0,0(s1)" in nputs loop
    integer str_load_count;
    integer str_load_file;
    integer nputs_entry_count;
    integer nputs_entry_file;
    initial begin
        str_load_count = 0;
        str_load_file = $fopen("/tmp/string_loads.txt", "w");
        nputs_entry_count = 0;
        nputs_entry_file = $fopen("/tmp/nputs_entry.txt", "w");
    end
    
    // Track nputs function entry - PC=0x190c is nputs entry point
    integer alu_calc_count;
    integer alu_calc_file;
    initial begin
        alu_calc_count = 0;
        alu_calc_file = $fopen("/tmp/alu_calc.txt", "w");
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h0000190c && nputs_entry_count < 50) begin
            $fwrite(nputs_entry_file, "[%0d] nputs_entry: a0(str_ptr)=0x%08x a1(len)=0x%08x\n",
                    nputs_entry_count,
                    dut.u_cpu_core.u_register_file.registers[10],  // a0 = x10
                    dut.u_cpu_core.u_register_file.registers[11]); // a1 = x11
            $fflush(nputs_entry_file);
            nputs_entry_count <= nputs_entry_count + 1;
        end
    end
    
    // Track instruction fetch for PC=0x1990
    integer ifetch_count;
    integer ifetch_file;
    initial begin
        ifetch_count = 0;
        ifetch_file = $fopen("/tmp/ifetch.txt", "w");
    end
    
    always @(posedge clk) begin
        if (rst_n && (dut.u_cpu_core.pc >= 32'h0000198c && dut.u_cpu_core.pc <= 32'h00001998) &&
            ifetch_count < 100) begin  
            $fwrite(ifetch_file, "[%0d] PC=0x%08x state=%0d instr=0x%08x ibus_addr=0x%08x ibus_ready=%0d ibus_rdata=0x%08x\n",
                    ifetch_count,
                    dut.u_cpu_core.pc,
                    dut.u_cpu_core.state,
                    dut.u_cpu_core.instruction,
                    dut.u_simple_bus.ibus_addr,
                    dut.u_simple_bus.ibus_ready,
                    dut.u_simple_bus.ibus_rdata);
            $fflush(ifetch_file);
            ifetch_count <= ifetch_count + 1;
        end
    end
    
    // Track ALU calculation for load at PC=0x1990 during EXECUTE state
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00001990 && 
            dut.u_cpu_core.state == 4'd4 && alu_calc_count < 200) begin  // STATE_EXECUTE = 4
            $fwrite(alu_calc_file, "[%0d] PC=0x%h EXEC: instr=0x%08x rs1_field=%0d s1=0x%08x rs1_addr=%0d rf_rs1=0x%08x alu_src_a=%0d alu_src_b=%0d alu_a=0x%08x alu_b=0x%08x result=0x%08x\n",
                    alu_calc_count,
                    dut.u_cpu_core.pc,
                    dut.u_cpu_core.instruction,
                    dut.u_cpu_core.instruction[19:15],
                    dut.u_cpu_core.u_register_file.registers[9],   // s1 = x9
                    dut.u_cpu_core.rf_rs1_addr,
                    dut.u_cpu_core.rf_rs1_data,
                    dut.u_cpu_core.alu_src_a,
                    dut.u_cpu_core.alu_src_b,
                    dut.u_cpu_core.alu_operand_a,
                    dut.u_cpu_core.alu_operand_b,
                    dut.u_cpu_core.alu_result);
            $fflush(alu_calc_file);
            alu_calc_count <= alu_calc_count + 1;
        end
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00001990 && 
            (dut.u_cpu_core.state == 4'd5 || dut.u_cpu_core.state == 4'd6) && str_load_count < 200) begin  // STATE_MEMORY=5 or STATE_MEMORY_WAIT=6
            $fwrite(str_load_file, "[%0d] PC=0x%h state=%0d s1=0x%08x alu_result_reg=0x%08x dbus_addr=0x%08x rdata=0x%08x char=0x%02x\n",
                    str_load_count,
                    dut.u_cpu_core.pc,
                    dut.u_cpu_core.state,
                    dut.u_cpu_core.u_register_file.registers[9],   // s1 = x9
                    dut.u_cpu_core.alu_result_reg,
                    dut.u_simple_bus.dbus_addr,
                    dut.u_simple_bus.dbus_rdata,
                    dut.u_simple_bus.dbus_rdata[7:0]);  // '.' for non-printable
            $fflush(str_load_file);
            str_load_count <= str_load_count + 1;
        end
    end
    
    // Track all UART register accesses (DISABLED - too verbose, causes display interleaving)
    // integer uart_access_count;
    // initial uart_access_count = 0;
    // always @(posedge clk) begin
    //     if (rst_n && dut.u_simple_bus.dbus_req && 
    //         (dut.u_simple_bus.dbus_addr >= 32'h10000000 && dut.u_simple_bus.dbus_addr <= 32'h10000007) &&
    //         dut.u_simple_bus.dbus_ready && uart_access_count < 50) begin
    //         if (dut.u_simple_bus.dbus_we) begin
    //             $display("[UART_ACCESS #%0d] WRITE addr=0x%h (reg=%0d) data=0x%02x PC=0x%h",
    //                      uart_access_count,
    //                      dut.u_simple_bus.dbus_addr,
    //                      dut.u_simple_bus.dbus_addr[2:0],
    //                      dut.u_simple_bus.dbus_wdata[7:0],
    //                      dut.u_cpu_core.pc);
    //         end else begin
    //             $display("[UART_ACCESS #%0d] READ  addr=0x%h (reg=%0d) data=0x%02x PC=0x%h",
    //                      uart_access_count,
    //                      dut.u_simple_bus.dbus_addr,
    //                      dut.u_simple_bus.dbus_addr[2:0],
    //                      dut.u_simple_bus.dbus_rdata[7:0],
    //                      dut.u_cpu_core.pc);
    //         end
    //         uart_access_count <= uart_access_count + 1;
    //     end
    // end
    
    // Track UART internal state (DISABLED - too verbose)
    // integer uart_state_log_count;
    // logic prev_tx_busy;
    // initial begin
    //     uart_state_log_count = 0;
    //     prev_tx_busy = 0;
    // end
    // always @(posedge clk) begin
    //     if (rst_n && uart_state_log_count < 100) begin
    //         if (dut.u_uart.tx_busy != prev_tx_busy) begin
    //             $display("[UART_STATE] time=%0dns tx_busy=%d->%d baud_counter=%0d bit_count=%0d",
    //                      $time,
    //                      prev_tx_busy,
    //                      dut.u_uart.tx_busy,
    //                      dut.u_uart.baud_counter,
    //                      dut.u_uart.tx_bit_count);
    //             prev_tx_busy <= dut.u_uart.tx_busy;
    //             uart_state_log_count <= uart_state_log_count + 1;
    //         end
    //     end
    // end

    // ========================================
    // CONSOLE_TBUF STORE DEBUGGING
    // ========================================
    
    // Track ALL stores to console_tbuf range (0x00041108 - 0x00041200)
    integer console_store_count;
    integer console_store_file;
    initial begin
        console_store_count = 0;
        console_store_file = $fopen("/tmp/console_stores.txt", "w");
    end
    
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && dut.u_simple_bus.dbus_we && 
            dut.u_simple_bus.dbus_addr >= 32'h00041108 && 
            dut.u_simple_bus.dbus_addr <= 32'h00041200 && 
            dut.u_simple_bus.dbus_ready &&
            console_store_count < 1000) begin
            // Determine store size from wstrb
            string size_str;
            case (dut.u_simple_bus.dbus_wstrb)
                4'b0001, 4'b0010, 4'b0100, 4'b1000: size_str = "BYTE";
                4'b0011, 4'b1100: size_str = "HALF";
                4'b1111: size_str = "WORD";
                default: size_str = "????";
            endcase
            
            $fwrite(console_store_file, "[%0d] PC=0x%04x addr=0x%04x wdata=0x%08x wstrb=0x%x size=%s\n",
                    console_store_count,
                    dut.u_cpu_core.pc,
                    dut.u_simple_bus.dbus_addr,
                    dut.u_simple_bus.dbus_wdata,
                    dut.u_simple_bus.dbus_wstrb,
                    size_str);
            $fflush(console_store_file);
            console_store_count <= console_store_count + 1;
        end
    end

    // ========================================
    // PRINT() FUNCTION DEBUGGING
    // ========================================
    
    // Track print() function calls at 0x21e4
    logic probe_print_entry;
    integer print_entry_count;
    initial begin
        probe_print_entry = 0;
        print_entry_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h000021e4 && print_entry_count < 10) begin
            $display("[PRINT_ENTRY #%0d] PC=0x21e4: a0(out_ptr)=0x%h a1(maxlen)=0x%h a2(fmt_ptr)=0x%h a3=0x%h",
                     print_entry_count,
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12],
                     dut.u_cpu_core.u_register_file.registers[13]);
            print_entry_count <= print_entry_count + 1;
        end
    end
    
    // Track print() at PC=0x2228 where it loads the buffer pointer
    logic probe_print_load_buf;
    integer print_load_buf_count;
    initial begin
        probe_print_load_buf = 0;
        print_load_buf_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00002228 && print_load_buf_count < 10) begin
            $display("[PRINT_LOAD_BUF #%0d] PC=0x2228: Loading buf ptr from a0(out)=0x%h mem[a0]=0x%h",
                     print_load_buf_count,
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_ram.memory[dut.u_cpu_core.u_register_file.registers[10] >> 2]);
            print_load_buf_count <= print_load_buf_count + 1;
        end
    end
    
    // Track print() at PC=0x2230 where it writes NULL terminator
    logic probe_print_null_write;
    integer print_null_write_count;
    initial begin
        probe_print_null_write = 0;
        print_null_write_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00002230 && print_null_write_count < 10) begin
            $display("[PRINT_NULL_WRITE #%0d] PC=0x2230: About to write NULL to addr=a4(buf_ptr)=0x%h",
                     print_null_write_count,
                     dut.u_cpu_core.u_register_file.registers[14]);
            print_null_write_count <= print_null_write_count + 1;
        end
    end
    
    // Track print() at PC=0x2354 - exit point
    logic probe_print_exit;
    integer print_exit_count;
    initial begin
        probe_print_exit = 0;
        print_exit_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00002354 && print_exit_count < 10) begin
            $display("[PRINT_EXIT #%0d] PC=0x2354: Exiting print() - s1(len)=0x%h",
                     print_exit_count,
                     dut.u_cpu_core.u_register_file.registers[9]);
            print_exit_count <= print_exit_count + 1;
        end
    end
    
    // Track printc() function at 0x1a40 (called from print for each char)
    logic probe_printc_entry;
    integer printc_entry_count;
    initial begin
        probe_printc_entry = 0;
        printc_entry_count = 0;
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_cpu_core.pc == 32'h00001a40 && printc_entry_count < 50) begin
            $display("[PRINTC_ENTRY #%0d] PC=0x1a40: a0(out)=0x%h a1(maxlen)=0x%h a2(char)=0x%02x '%c' a3(flags)=0x%h",
                     printc_entry_count,
                     dut.u_cpu_core.u_register_file.registers[10],
                     dut.u_cpu_core.u_register_file.registers[11],
                     dut.u_cpu_core.u_register_file.registers[12],
                     (dut.u_cpu_core.u_register_file.registers[12] >= 32 && 
                      dut.u_cpu_core.u_register_file.registers[12] <= 126) ? 
                      dut.u_cpu_core.u_register_file.registers[12][7:0] : 8'h2e,
                     dut.u_cpu_core.u_register_file.registers[13]);
            printc_entry_count <= printc_entry_count + 1;
        end
    end
    
    // Track ALL memory writes to console_tbuf region (0x41108-0x41188)
    integer tbuf_write_count;
    integer tbuf_write_file;
    initial begin
        tbuf_write_count = 0;
        tbuf_write_file = $fopen("/tmp/console_tbuf_writes.txt", "w");
    end
    always @(posedge clk) begin
        if (rst_n && dut.u_simple_bus.dbus_req && dut.u_simple_bus.dbus_we &&
            dut.u_simple_bus.dbus_addr >= 32'h00041108 && 
            dut.u_simple_bus.dbus_addr < 32'h00041188 &&
            dut.u_simple_bus.dbus_ready && tbuf_write_count < 200) begin
            $fwrite(tbuf_write_file, "[%0d] PC=0x%h addr=0x%h wdata=0x%08x wstrb=0x%x offset=%0d\n",
                    tbuf_write_count,
                    dut.u_cpu_core.pc,
                    dut.u_simple_bus.dbus_addr,
                    dut.u_simple_bus.dbus_wdata,
                    dut.u_simple_bus.dbus_wstrb,
                    dut.u_simple_bus.dbus_addr - 32'h00041108);
            $fflush(tbuf_write_file);
            
            // Also display to console
            if (tbuf_write_count < 50) begin
                $display("[TBUF_WRITE #%0d] PC=0x%h addr=0x%h wdata=0x%08x wstrb=0x%x bytes=[%02x %02x %02x %02x]",
                         tbuf_write_count,
                         dut.u_cpu_core.pc,
                         dut.u_simple_bus.dbus_addr,
                         dut.u_simple_bus.dbus_wdata,
                         dut.u_simple_bus.dbus_wstrb,
                         dut.u_simple_bus.dbus_wdata[7:0],
                         dut.u_simple_bus.dbus_wdata[15:8],
                         dut.u_simple_bus.dbus_wdata[23:16],
                         dut.u_simple_bus.dbus_wdata[31:24]);
            end
            tbuf_write_count <= tbuf_write_count + 1;
        end
    end

    // ========================================
    // CONSOLE_TBUF MEMORY DUMP PROBE
    // ========================================
    // Dump first 128 bytes of console_tbuf at 0x00041108 when PC=0x0002a74 (after print() finishes)
    logic console_tbuf_dumped;
    integer console_tbuf_dump_file;
    initial console_tbuf_dumped = 0;
    
    always @(posedge clk) begin
        if (rst_n && !console_tbuf_dumped && dut.u_cpu_core.pc == 32'h0002a74) begin
            console_tbuf_dumped <= 1;
            console_tbuf_dump_file = $fopen("/tmp/console_tbuf_dump.txt", "w");
            
            $display("[CONSOLE_TBUF_DUMP] Dumping 128 bytes at 0x00041108 (PC=0x0002a74)");
            $fwrite(console_tbuf_dump_file, "=== CONSOLE_TBUF DUMP at PC=0x0002a74 ===\n");
            $fwrite(console_tbuf_dump_file, "Base address: 0x00041108\n");
            $fwrite(console_tbuf_dump_file, "Dumping 128 bytes:\n\n");
            
            // Dump 128 bytes starting from console_tbuf (0x00041108)
            for (int i = 0; i < 128; i = i + 1) begin
                logic [31:0] addr;
                logic [31:0] word_addr;
                logic [7:0] byte_val;
                
                addr = 32'h00041108 + i;
                word_addr = addr >> 2;  // Convert byte address to word address
                
                // Extract the correct byte from the word based on lower 2 bits of address
                case (addr[1:0])
                    2'b00: byte_val = dut.u_ram.memory[word_addr][7:0];
                    2'b01: byte_val = dut.u_ram.memory[word_addr][15:8];
                    2'b10: byte_val = dut.u_ram.memory[word_addr][23:16];
                    2'b11: byte_val = dut.u_ram.memory[word_addr][31:24];
                endcase
                
                // Write formatted output: [offset] addr=0xXXXXXXXX data=0xXX 'c'
                if (byte_val >= 32 && byte_val <= 126) begin
                    // Printable ASCII
                    $fwrite(console_tbuf_dump_file, "[%03d] addr=0x%08x data=0x%02x '%c'\n", 
                            i, addr, byte_val, byte_val);
                end else if (byte_val == 0) begin
                    // NULL
                    $fwrite(console_tbuf_dump_file, "[%03d] addr=0x%08x data=0x%02x '\\0'\n", 
                            i, addr, byte_val);
                end else if (byte_val == 10) begin
                    // Newline
                    $fwrite(console_tbuf_dump_file, "[%03d] addr=0x%08x data=0x%02x '\\n'\n", 
                            i, addr, byte_val);
                end else if (byte_val == 13) begin
                    // Carriage return
                    $fwrite(console_tbuf_dump_file, "[%03d] addr=0x%08x data=0x%02x '\\r'\n", 
                            i, addr, byte_val);
                end else begin
                    // Non-printable
                    $fwrite(console_tbuf_dump_file, "[%03d] addr=0x%08x data=0x%02x '.'\n", 
                            i, addr, byte_val);
                end
            end
            
            $fwrite(console_tbuf_dump_file, "\n=== END DUMP ===\n");
            $fflush(console_tbuf_dump_file);
            $fclose(console_tbuf_dump_file);
            $display("[CONSOLE_TBUF_DUMP] Dump complete - written to /tmp/console_tbuf_dump.txt");
        end
    end

endmodule
