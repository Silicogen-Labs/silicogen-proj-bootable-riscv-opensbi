#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_soc.h"
#include "Vtb_soc___024root.h"  // For accessing internal signals
#include <iostream>
#include <memory>

// Test result memory locations
#define TEST_RESULT_BASE 0x3F00
#define TEST_STATUS_ADDR 0x3FFC
#define TEST_MAGIC_DONE  0xDEADBEEF

int main(int argc, char** argv) {
    // Create context for Verilator
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);
    
    // Create instance of the testbench
    const std::unique_ptr<Vtb_soc> tb{new Vtb_soc{contextp.get()}};
    
    // Create VCD trace (disabled by default for speed)
    VerilatedVcdC* tfp = nullptr;
    bool enable_trace = false;  // Set to true to enable VCD tracing
    
    if (enable_trace) {
        tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);
        tfp->open("sim/waveforms/tb_soc.vcd");
        std::cout << "VCD tracing enabled" << std::endl;
    }
    
    std::cout << "=== Starting RISC-V SoC Verilator Simulation ===" << std::endl;
    
    // Initialize signals
    tb->clk = 0;
    tb->rst_n = 0;
    
    uint64_t time = 0;
    uint64_t cycles = 0;
    const uint64_t MAX_TIME = 10000000000; // 10000ms timeout (500M cycles at 50MHz) - increased for OpenSBI boot
    bool test_complete = false;
    
    // Simulation loop - drive clock from C++
    while (!contextp->gotFinish() && time < MAX_TIME && !test_complete) {
        // Negative edge
        tb->clk = 0;
        tb->eval();
        if (enable_trace && tfp) {
            tfp->dump(time);
        }
        time += 10;  // 10ns (half of 20ns period)
        
        // Release reset after 200ns (10 clock cycles)
        if (time >= 200 && time < 220 && tb->rst_n == 0) {
            tb->rst_n = 1;
            std::cout << "Reset released at time " << time << " ns" << std::endl;
        }
        
        // Positive edge
        tb->clk = 1;
        tb->eval();
        if (enable_trace && tfp) {
            tfp->dump(time);
        }
        time += 10;  // 10ns (half of 20ns period)
        cycles++;
        
        // Check for test completion every 1000 cycles
        if (cycles % 1000 == 0 && tb->rst_n) {
            // Access RAM memory directly (word-aligned)
            uint32_t status_word_addr = TEST_STATUS_ADDR >> 2;
            if (status_word_addr < 1048576) {  // Within 4MB RAM
                uint32_t status = tb->rootp->tb_soc__DOT__dut__DOT__u_ram__DOT__memory[status_word_addr];
                if (status == TEST_MAGIC_DONE) {
                    std::cout << "\n=== Test Completion Detected at cycle " << cycles << " ===" << std::endl;
                    test_complete = true;
                }
            }
        }
        
        // Debug: show PC and first test result every 50k cycles
        if (cycles % 50000 == 0 && cycles > 0 && tb->rst_n) {
            uint32_t pc = tb->rootp->tb_soc__DOT__dut__DOT__u_cpu_core__DOT__pc;
            uint32_t test0 = tb->rootp->tb_soc__DOT__dut__DOT__u_ram__DOT__memory[(TEST_RESULT_BASE >> 2)];
            std::cout << "Cycles: " << cycles / 1000 << "k, PC: 0x" << std::hex << pc 
                      << ", Test[0]: 0x" << test0 << std::dec << std::endl;
        }
    }
    
    // Final evaluation
    tb->eval();
    
    // Check and report test results
    std::cout << "\n=== Checking Test Results ===" << std::endl;
    
    // Debug: print first 20 words of test result area and status
    std::cout << "Debug memory dump:" << std::endl;
    std::cout << "  TEST_RESULT_BASE (0x3F00 >> 2) = 0x" << std::hex << (TEST_RESULT_BASE >> 2) << std::dec << std::endl;
    std::cout << "  TEST_STATUS_ADDR (0x3FFC >> 2) = 0x" << std::hex << (TEST_STATUS_ADDR >> 2) << std::dec << std::endl;
    
    uint32_t status = tb->rootp->tb_soc__DOT__dut__DOT__u_ram__DOT__memory[TEST_STATUS_ADDR >> 2];
    std::cout << "  Status word at 0x3FFC = 0x" << std::hex << status << std::dec << std::endl;
    
    std::cout << "First 20 test result values:" << std::endl;
    for (int i = 0; i < 20; i++) {
        uint32_t result_addr = (TEST_RESULT_BASE >> 2) + i;
        uint32_t result = tb->rootp->tb_soc__DOT__dut__DOT__u_ram__DOT__memory[result_addr];
        std::cout << "  [" << i << "] @0x" << std::hex << result_addr << std::dec << " = 0x" << std::hex << result << std::dec << std::endl;
    }
    
    int test_passed = 0;
    int test_failed = 0;
    int test_total = 0;
    
    for (int i = 0; i < 64; i++) {
        uint32_t result_addr = (TEST_RESULT_BASE >> 2) + i;
        if (result_addr < 1048576) {
            uint32_t result = tb->rootp->tb_soc__DOT__dut__DOT__u_ram__DOT__memory[result_addr];
            
            if (result != 0) {
                test_total++;
                if (result == 1) {
                    test_passed++;
                    std::cout << "  Test " << i << ": PASS" << std::endl;
                } else {
                    test_failed++;
                    std::cout << "  Test " << i << ": FAIL (value=0x" << std::hex << result << std::dec << ")" << std::endl;
                }
            }
        }
    }
    
    // Print summary
    std::cout << "\n=== Test Summary ===" << std::endl;
    std::cout << "Total Tests:  " << test_total << std::endl;
    std::cout << "Passed:       " << test_passed << std::endl;
    std::cout << "Failed:       " << test_failed << std::endl;
    std::cout << "Total Cycles: " << cycles << std::endl;
    std::cout << "Simulation Time: " << time << " ns (" << time / 1000000 << " ms)" << std::endl;
    
    if (test_failed == 0 && test_total > 0) {
        std::cout << "\n*** ALL TESTS PASSED ***\n" << std::endl;
    } else if (test_total == 0) {
        std::cout << "\n*** NO TESTS DETECTED ***" << std::endl;
        std::cout << "(This may be an integration test without self-checking)\n" << std::endl;
    } else {
        std::cout << "\n*** " << test_failed << " TESTS FAILED ***\n" << std::endl;
    }
    
    // Final model cleanup
    tb->final();
    
    // Close trace
    if (enable_trace && tfp) {
        tfp->close();
        delete tfp;
    }
    
    return (test_failed == 0 && test_total > 0) ? 0 : 1;
}
