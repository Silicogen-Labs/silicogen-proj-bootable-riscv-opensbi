# Testing Strategy for RISC-V Processor

**Tools:** 100% Free & Open Source (Verilator + RISC-V toolchain)  
**Approach:** Directed testing with self-checking  
**No commercial licenses required!**

---

## Current Testing Status

### What We Have
- ✅ Basic SoC testbench (`sim/testbenches/tb_soc.sv`)
- ✅ One test program (`sw/tests/hello.S`)
- ✅ UART output monitoring
- ✅ Waveform generation (VCD)
- ✅ Verilator simulation (fast & free)

### What We Need
- ⬜ Comprehensive instruction tests
- ⬜ Self-checking mechanism
- ⬜ Multiple test programs
- ⬜ Automated test runner
- ⬜ Coverage tracking
- ⬜ Regression test suite

---

## Testing Approach: No UVM Needed!

### Why We Don't Need UVM

**UVM is designed for:**
- Large SoC verification with many blocks
- Constrained random testing
- Transaction-level modeling
- Reusable VIP (Verification IP)

**Our project needs:**
- Instruction-level testing
- Deterministic directed tests
- Fast simulation turnaround
- Learning-focused approach

**Our approach with Verilator is actually BETTER for:**
- ✅ Faster simulation (10-100x faster than UVM)
- ✅ Simpler to understand and debug
- ✅ More deterministic (no random failures)
- ✅ Easier to get started
- ✅ Free tools only!

---

## Testing Layers

### Layer 1: Instruction-Level Tests (Highest Priority)

**Goal:** Verify every instruction works correctly

**Method:** Write assembly programs that:
1. Execute specific instructions
2. Store results to known memory locations
3. Testbench reads memory and checks results

**Example Test Structure:**
```assembly
# Test: ADD instruction
test_add:
    li t0, 5          # Load immediate
    li t1, 10         # Load immediate
    add t2, t0, t1    # t2 = t0 + t1 = 15
    
    # Store result for checking
    li t3, 0x3F00     # Test result area
    sw t2, 0(t3)      # Store result
    
    # Expected value
    li t4, 15
    sw t4, 4(t3)      # Store expected
    
    ret
```

**Testbench checks:**
```systemverilog
// After test completes
expected = mem[0x3F04];
actual = mem[0x3F00];
if (actual !== expected) begin
    $error("ADD test failed: expected %d, got %d", expected, actual);
    test_passed = 0;
end
```

### Layer 2: Feature-Level Tests

**Tests to create:**
1. **ALU Tests** (`sw/tests/test_alu.S`)
   - All arithmetic: ADD, SUB, ADDI
   - All logical: AND, OR, XOR, ANDI, ORI, XORI
   - All shifts: SLL, SRL, SRA, SLLI, SRLI, SRAI
   - All comparisons: SLT, SLTU, SLTI, SLTIU

2. **Memory Tests** (`sw/tests/test_memory.S`)
   - All loads: LB, LBU, LH, LHU, LW
   - All stores: SB, SH, SW
   - Aligned and unaligned accesses
   - Boundary conditions

3. **Branch Tests** (`sw/tests/test_branch.S`)
   - All branch types: BEQ, BNE, BLT, BGE, BLTU, BGEU
   - Forward and backward branches
   - Taken and not-taken paths

4. **Jump Tests** (`sw/tests/test_jump.S`)
   - JAL with various offsets
   - JALR with register targets
   - Return address verification

5. **Upper Immediate Tests** (`sw/tests/test_upper.S`)
   - LUI (Load Upper Immediate)
   - AUIPC (Add Upper Immediate to PC)

6. **M-Extension Tests** (`sw/tests/test_muldiv.S`)
   - MUL, MULH, MULHSU, MULHU
   - DIV, DIVU, REM, REMU
   - Edge cases: division by zero, overflow

7. **CSR Tests** (`sw/tests/test_csr.S`)
   - CSRRW, CSRRS, CSRRC
   - CSRRWI, CSRRSI, CSRRCI
   - All CSR registers

### Layer 3: System-Level Tests

1. **Interrupt Tests**
   - Timer interrupt delivery
   - External interrupt handling
   - Interrupt nesting

2. **Exception Tests**
   - Illegal instruction
   - Misaligned access
   - ECALL/EBREAK

3. **Integration Tests**
   - Full programs (like hello.S)
   - Multi-function programs
   - Eventually: OpenSBI boot

---

## Test Infrastructure

### Directory Structure
```
sw/
├── tests/
│   ├── hello.S              # Existing integration test
│   ├── test_alu.S           # NEW: ALU instruction tests
│   ├── test_memory.S        # NEW: Load/store tests
│   ├── test_branch.S        # NEW: Branch tests
│   ├── test_jump.S          # NEW: Jump tests
│   ├── test_upper.S         # NEW: LUI/AUIPC tests
│   ├── test_muldiv.S        # NEW: M-extension tests
│   ├── test_csr.S           # NEW: CSR tests
│   └── test_framework.h     # NEW: Common test macros
└── scripts/
    ├── run_all_tests.sh     # NEW: Automated test runner
    └── check_results.py     # NEW: Parse results
```

### Test Framework Macros

Create `sw/tests/test_framework.h`:
```assembly
# Test framework macros for self-checking tests

# Memory region for test results
.equ TEST_RESULT_BASE, 0x3F00
.equ TEST_PASS, 0x1
.equ TEST_FAIL, 0x0

# Macro: Start test
.macro TEST_START test_name
    .section .rodata
test_name_\test_name:
    .string "\test_name"
    .section .text
.endm

# Macro: Check result
.macro CHECK_EQUAL reg_actual, reg_expected, test_id
    beq \reg_actual, \reg_expected, 1f
    # Test failed
    li t0, TEST_RESULT_BASE
    li t1, TEST_FAIL
    sw t1, \test_id*4(t0)
    j 2f
1:  # Test passed
    li t0, TEST_RESULT_BASE
    li t1, TEST_PASS
    sw t1, \test_id*4(t0)
2:
.endm

# Macro: Report all results
.macro TEST_REPORT
    li t0, TEST_RESULT_BASE
    li t1, 0xDEADBEEF  # Magic end marker
    sw t1, 0x3FC(t0)
.endm
```

### Testbench Improvements

**Enhanced tb_soc.sv features:**
1. **Test result checking** - Read memory at 0x3F00 and verify
2. **Automatic pass/fail** - Report at end of simulation
3. **Multiple test support** - Parameter to select which test to run
4. **Coverage tracking** - Track which instructions were executed

---

## Automated Test Flow

### Shell Script: `sw/scripts/run_all_tests.sh`
```bash
#!/bin/bash

TESTS=(
    "test_alu"
    "test_memory"
    "test_branch"
    "test_jump"
    "test_upper"
    "test_muldiv"
)

PASSED=0
FAILED=0

for test in "${TESTS[@]}"; do
    echo "Running $test..."
    
    # Compile test
    make TEST=$test sw
    
    # Run simulation
    ./build/verilator/Vtb_soc > build/${test}_output.txt
    
    # Check results
    if grep -q "TEST PASSED" build/${test}_output.txt; then
        echo "  ✓ PASSED"
        ((PASSED++))
    else
        echo "  ✗ FAILED"
        ((FAILED++))
    fi
done

echo ""
echo "========================================="
echo "Test Results: $PASSED passed, $FAILED failed"
echo "========================================="

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
```

---

## Coverage Tracking (Without Commercial Tools)

### Method 1: Instruction Coverage
Track which instructions were executed:

**In testbench:**
```systemverilog
// Track executed instructions
logic [31:0] instr_coverage [0:255];
int unique_instrs = 0;

always @(posedge clk) begin
    if (dut.u_cpu_core.state == STATE_DECODE) begin
        logic [6:0] opcode = dut.u_cpu_core.opcode;
        logic [2:0] funct3 = dut.u_cpu_core.funct3;
        logic [6:0] funct7 = dut.u_cpu_core.funct7;
        
        // Create unique instruction ID
        logic [31:0] instr_id = {funct7, funct3, opcode};
        
        // Mark as covered
        if (!instr_coverage[instr_id]) begin
            instr_coverage[instr_id] = 1;
            unique_instrs++;
        end
    end
end

// Report at end
final begin
    $display("Coverage: %d/%d instructions executed", unique_instrs, 47);
    // 47 = number of RV32I instructions
end
```

### Method 2: Branch Coverage
Track taken/not-taken for each branch:

```systemverilog
typedef struct {
    int taken;
    int not_taken;
} branch_coverage_t;

branch_coverage_t branch_cov [0:1023];  // Track up to 1024 branches

always @(posedge clk) begin
    if (dut.u_cpu_core.is_branch) begin
        logic [31:0] pc = dut.u_cpu_core.pc;
        if (dut.u_cpu_core.branch_taken)
            branch_cov[pc[11:2]].taken++;
        else
            branch_cov[pc[11:2]].not_taken++;
    end
end
```

---

## Comparison: UVM vs Our Approach

| Feature | UVM + Commercial Sim | Our Verilator Approach |
|---------|---------------------|------------------------|
| **Cost** | $10,000+ per year | FREE |
| **Simulation Speed** | Slow (event-driven) | Fast (cycle-accurate) |
| **Setup Complexity** | High (weeks to learn) | Low (start today) |
| **Random Testing** | Excellent | Limited (but not needed) |
| **Directed Testing** | Possible | Excellent |
| **Coverage** | Automatic | Manual tracking |
| **Debugging** | Complex | Straightforward |
| **Industry Use** | Large companies | Google, Western Digital, etc. |
| **Learning Curve** | Steep | Moderate |
| **Our Project** | Overkill | Perfect fit |

---

## Recommendation

**For this project, stick with Verilator!**

**Phase 5 Testing Plan:**
1. Create test framework (`test_framework.h`)
2. Write directed tests for each instruction category
3. Enhance testbench with self-checking
4. Create automated test runner script
5. Track coverage manually
6. Build regression test suite

**This approach will:**
- ✅ Teach you proper verification techniques
- ✅ Give you comprehensive test coverage
- ✅ Cost $0
- ✅ Run fast
- ✅ Be simple to understand and debug
- ✅ Be sufficient for eventual OpenSBI boot

**Save UVM for when:**
- You're working at a company with licenses
- You're verifying a complex SoC with many blocks
- You need constrained random testing
- You have time to learn UVM (6+ months)

---

## Next Steps

1. **Update TODO.md** with testing tasks
2. **Create test framework macros**
3. **Write first directed test** (test_alu.S)
4. **Enhance testbench** with self-checking
5. **Create test runner script**
6. **Run and iterate**

**All with FREE tools!** 🚀
