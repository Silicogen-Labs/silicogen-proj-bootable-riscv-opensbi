# Quick Start Guide - Fix Phase 5 Simulation

**Problem:** Simulation hangs at time=0  
**Solution:** Drive clock from C++ instead of SystemVerilog timing  
**Estimated Time:** 15-30 minutes

---

## Step-by-Step Fix

### 1. Update sim/sim_main.cpp

Replace the simulation loop with this:

```cpp
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_soc.h"
#include <iostream>

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);
    
    const std::unique_ptr<Vtb_soc> tb{new Vtb_soc{contextp.get()}};
    
    // VCD trace (disabled by default for speed)
    VerilatedVcdC* tfp = nullptr;
    bool enable_trace = false;
    
    if (enable_trace) {
        tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);
        tfp->open("sim/waveforms/tb_soc.vcd");
    }
    
    std::cout << "=== Starting RISC-V SoC Verilator Simulation ===" << std::endl;
    
    // Initialize
    tb->clk = 0;
    tb->rst_n = 0;
    
    uint64_t time = 0;
    const uint64_t MAX_TIME = 100000000; // 100ms
    
    // Simulation loop - drive clock from C++
    while (!contextp->gotFinish() && time < MAX_TIME) {
        // Negative edge
        tb->clk = 0;
        tb->eval();
        if (enable_trace && tfp) tfp->dump(time);
        time += 10;
        
        // Release reset after 10 clocks
        if (time == 200) {
            tb->rst_n = 1;
        }
        
        // Positive edge
        tb->clk = 1;
        tb->eval();
        if (enable_trace && tfp) tfp->dump(time);
        time += 10;
        
        // Progress indicator
        if (time % 1000000 == 0) {
            std::cout << "Time: " << time << " ns" << std::endl;
        }
    }
    
    tb->final();
    
    if (enable_trace && tfp) {
        tfp->close();
        delete tfp;
    }
    
    std::cout << "=== Simulation Complete ===" << std::endl;
    std::cout << "Total time: " << time << " ns" << std::endl;
    
    return 0;
}
```

### 2. Remove --timing flag from Makefile

Edit `Makefile`, change:
```make
VFLAGS = --cc --exe --build --trace --timing
```
To:
```make
VFLAGS = --cc --exe --build --trace
```

### 3. Update testbench to remove clock generator

Edit `sim/testbenches/tb_soc.sv`, comment out or remove:
```systemverilog
// Clock generation: 50MHz (20ns period)
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end
```

And remove the reset sequence:
```systemverilog
// Reset sequence (active low) - NOW HANDLED IN C++
// rst_n = 0;
// repeat(10) @(posedge clk);
// rst_n = 1;
```

### 4. Rebuild and test

```bash
cd /silicogenplayground/bootble-vm-riscv
make clean
make TEST=test_alu run
```

Expected output:
```
=== Starting RISC-V SoC Verilator Simulation ===
Time: 1000000 ns
Time: 2000000 ns
...
=== Test Completion Detected ===
=== Checking Test Results ===
  Test 0: PASS
  Test 1: PASS
  ...
=== Test Summary ===
Total Tests: 44
Passed: 44
Failed: 0

*** ALL TESTS PASSED ***
```

---

## Alternative: Minimal Fix

If the above doesn't work, try this simpler version:

Just replace the while loop in sim_main.cpp:

```cpp
// Simple clock driving
while (!contextp->gotFinish() && time < 100000000) {
    tb->clk = (time % 20) < 10 ? 0 : 1;
    
    if (time == 100) tb->rst_n = 0;
    if (time == 200) tb->rst_n = 1;
    
    tb->eval();
    time++;
}
```

---

## Quick Test Commands

```bash
# Test the fix
make clean && make TEST=test_alu sw sim && ./build/verilator/Vtb_soc

# If it works, run all tests
make TEST=test_alu run
make TEST=test_memory run  
make TEST=test_branch run
make TEST=test_muldiv run

# Or use the automated script
./sw/scripts/run_all_tests.sh
```

---

## Expected Results

- **test_alu:** 44 tests (arithmetic, logical, shifts, comparisons)
- **test_memory:** 46 tests (loads, stores, alignment)
- **test_branch:** 40 tests (branches, jumps)
- **test_muldiv:** 57 tests (M-extension)

**Total: 187 tests - should all PASS if processor is working correctly!**

---

## If Tests Fail

1. Check which test failed (testbench reports test ID)
2. Look at the test in the .S file to see what it was checking
3. Enable VCD tracing (`enable_trace = true` in sim_main.cpp)
4. Rebuild: `make TEST=test_alu sim`
5. View waveform: `gtkwave sim/waveforms/tb_soc.vcd`
6. Find the failing instruction and debug the processor

---

## Success Criteria

✅ Simulation runs and advances time  
✅ Test completion detected (0xDEADBEEF at 0x3FFC)  
✅ All 187 tests pass  
✅ No processor bugs found  

**Then Phase 5 is 100% COMPLETE!** 🎉

Next: Phase 6 (Trap Handling & CSRs)
