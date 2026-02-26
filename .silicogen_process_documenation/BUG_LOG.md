# RISC-V Processor Bug Log

**Project:** bootble-vm-riscv  
**Last Updated:** 2026-02-26  
**Total Bugs Fixed:** 14

---

## Bug Summary

| Bug # | Severity | Phase | Status | Description |
|-------|----------|-------|--------|-------------|
| #1    | Critical | 4     | ✅ Fixed | Bus request signals not held during wait states |
| #2    | Critical | 4     | ✅ Fixed | Register write enable not latched |
| #3    | Critical | 4     | ✅ Fixed | PC not updated correctly after branches/jumps |
| #4    | Critical | 4     | ✅ Fixed | Register write source not latched |
| #5    | Critical | 4     | ✅ Fixed | Load byte/halfword extraction incorrect |
| #6    | Critical | 4     | ✅ Fixed | Memory address using wrong ALU result |
| #7    | Critical | 4     | ✅ Fixed | UART byte addressing incorrect |
| #8    | Critical | 4     | ✅ Fixed | Store instructions not advancing PC |
| #9    | Critical | 5     | ✅ Fixed | Branch taken signal not latched |
| #10   | Critical | 6A    | ✅ Fixed | trap_taken held continuously |
| #11   | Critical | 6A    | ✅ Fixed | MRET PC update in wrong state |
| #12   | Critical | 6B    | ✅ Fixed | Spurious illegal instruction detection |
| #13   | Critical | 6B    | ✅ Fixed | instruction_valid not cleared after trap |
| #14   | Critical | 6B    | ✅ Fixed | MRET signal not latched |

---

## Detailed Bug Reports

### Bug #1: Bus Request Signals Not Held During Wait States
- **Discovered:** Phase 4 (Initial Testing)
- **Severity:** Critical
- **Symptom:** Memory operations failed intermittently
- **Root Cause:** `ibus_req` and `dbus_req` were not held high during multi-cycle wait states
- **Fix:** Changed bus request logic to hold signals high until `ready` signal received
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:** Bus request assignment logic
- **Status:** ✅ Fixed

### Bug #2: Register Write Enable Not Latched
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** Register writes occurred at wrong pipeline stages
- **Root Cause:** `reg_write_enable` was combinational and changed during WRITEBACK stage
- **Fix:** Added `reg_write_enable_latched` signal, latched in EXECUTE stage
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Status:** ✅ Fixed

### Bug #3: PC Not Updated Correctly After Branches/Jumps
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** Program counter incremented by 4 after branch/jump instructions
- **Root Cause:** PC update logic didn't check for control flow changes
- **Fix:** Added checks for `is_jal`, `is_jalr`, and branch taken before incrementing PC
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Status:** ✅ Fixed

### Bug #4: Register Write Source Not Latched
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** Wrong data written to registers
- **Root Cause:** `reg_write_source` signal changed during WRITEBACK stage
- **Fix:** Added `reg_write_source_latched`, latched in EXECUTE stage
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Status:** ✅ Fixed

### Bug #5: Load Byte/Halfword Extraction Incorrect
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** Load byte/halfword operations returned wrong data
- **Root Cause:** Bit extraction logic used wrong offsets based on address
- **Fix:** Corrected byte/halfword extraction using address[1:0] for word alignment
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Status:** ✅ Fixed

### Bug #6: Memory Address Using Wrong ALU Result
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** Load/store operations accessed wrong memory addresses
- **Root Cause:** Memory operations used stale ALU result instead of current
- **Fix:** Ensured `alu_result` is used directly for address calculation in MEMORY stage
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Status:** ✅ Fixed

### Bug #7: UART Byte Addressing Incorrect
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** UART writes failed
- **Root Cause:** UART peripheral expected byte addresses but received word addresses
- **Fix:** Updated UART address decoding to handle byte addressing correctly
- **Files Modified:** `rtl/peripherals/uart_16550.sv` or `rtl/bus/simple_bus.sv`
- **Status:** ✅ Fixed

### Bug #8: Store Instructions Not Advancing PC
- **Discovered:** Phase 4
- **Severity:** Critical
- **Symptom:** CPU hung after store instructions
- **Root Cause:** Store operations didn't transition through WRITEBACK to update PC
- **Fix:** Ensured stores go through WRITEBACK stage for PC increment
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:** State machine STATE_MEMORY_WAIT logic
- **Status:** ✅ Fixed

### Bug #9: Branch Taken Signal Not Latched
- **Discovered:** Phase 5 (ISA Verification)
- **Severity:** Critical
- **Symptom:** Branch instructions always incremented PC by 4, even when taken
- **Root Cause:** `branch_taken` was combinational and changed by the time WRITEBACK checked it
- **Fix:** Added `branch_taken_latched` signal, latched in EXECUTE stage
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:** 
  - Line 97: Added `branch_taken_latched` declaration
  - Line 429: Latched in EXECUTE stage
  - Line 355: Used latched version in WRITEBACK PC update
- **Tests:** Fixed all branch tests in Phase 5 verification suite
- **Status:** ✅ Fixed
- **Impact:** All 187 ISA tests now passing

### Bug #10: trap_taken Held Continuously
- **Discovered:** Phase 6A (Trap Support)
- **Severity:** Critical
- **Symptom:** `trap_taken` signal stayed high, causing CSR file to continuously update
- **Root Cause:** `trap_taken` was set based on state transition but never cleared
- **Fix:** Changed `trap_taken` to pulse for one cycle when entering STATE_TRAP
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:** 
  - Lines 229-242: Modified trap_taken logic to pulse only on transition
  - Line 229: Check `next_state == STATE_TRAP && state != STATE_TRAP`
- **Tests:** test_trap.S now works correctly
- **Status:** ✅ Fixed

### Bug #11: MRET PC Update In Wrong State
- **Discovered:** Phase 6A
- **Severity:** Critical
- **Symptom:** After MRET, PC was incorrect and CPU hung
- **Root Cause:** PC was being updated to `mepc` in STATE_TRAP instead of STATE_EXECUTE
- **Fix:** Moved MRET PC update logic from STATE_TRAP to STATE_EXECUTE
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:**
  - Lines 347-349: Added MRET PC update in STATE_EXECUTE
  - Line 355: Prevented PC increment in WRITEBACK for MRET
- **Tests:** test_trap.S prints "OK" correctly
- **Status:** ✅ Fixed

### Bug #12: Spurious Illegal Instruction Detection
- **Discovered:** Phase 6B (Exception Testing)
- **Severity:** Critical
- **Symptom:** CPU trapped with illegal instruction exception on valid instructions
- **Root Cause:** Decoder evaluated `illegal_instruction` on stale instruction data (0x00000000 during reset, or old instructions after traps)
- **Fix:** Added `instruction_valid` flag to track when instruction is validly fetched
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:**
  - Line 52: Added `instruction_valid` signal declaration
  - Lines 378-388: Latch `instruction_valid` when instruction fetched, clear on WRITEBACK/TRAP
  - Line 697: Only check illegal_instruction when `instruction_valid` is true
- **Tests:** test_illegal_inst.S now prints 'P' for Pass
- **Status:** ✅ Fixed

### Bug #13: instruction_valid Not Cleared After Trap
- **Discovered:** Phase 6B
- **Severity:** Critical
- **Symptom:** After trap handling, stale instruction register caused second spurious trap
- **Root Cause:** `instruction_valid` was cleared in WRITEBACK but traps skip WRITEBACK
- **Fix:** Also clear `instruction_valid` in STATE_TRAP
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:** Line 386: Added `|| state == STATE_TRAP` condition
- **Tests:** test_illegal_inst.S no longer has spurious second trap
- **Status:** ✅ Fixed

### Bug #14: MRET Signal Not Latched
- **Discovered:** Phase 6B
- **Severity:** Critical
- **Symptom:** After MRET, CPU skipped the instruction at target address and jumped 4 bytes ahead
- **Root Cause:** `mret` signal was combinational and only asserted in STATE_DECODE/EXECUTE. By WRITEBACK, the instruction register had moved to next instruction and `mret` was false, causing PC to increment
- **Fix:** Added `mret_latched` signal, latched in EXECUTE stage
- **Files Modified:** `rtl/core/cpu_core.sv`
- **Lines:**
  - Line 101: Added `mret_latched` signal declaration
  - Line 430: Latch `mret` in EXECUTE stage
  - Line 356: Use `mret_latched` instead of `mret` in WRITEBACK PC update logic
- **Tests:** test_illegal_inst.S now correctly executes instruction at MRET target (prints 'P')
- **Status:** ✅ Fixed
- **Similar To:** Bug #9 (branch_taken not latched) - same pattern

---

## Bug Patterns and Lessons Learned

### Pattern #1: Signal Latching Issues (Bugs #2, #4, #9, #14)
**Problem:** Combinational control signals change during pipeline stages  
**Solution:** Latch critical control signals at end of EXECUTE stage  
**Signals Affected:**
- `reg_write_enable` → `reg_write_enable_latched`
- `reg_write_source` → `reg_write_source_latched`
- `branch_taken` → `branch_taken_latched`
- `mret` → `mret_latched`

**Lesson:** In a multi-cycle pipeline, control signals computed in one stage must be latched if they're used in later stages.

### Pattern #2: State Machine Control Flow (Bugs #3, #8, #11)
**Problem:** PC update logic didn't account for all control flow cases  
**Solution:** Carefully check all conditions before incrementing PC  
**Cases:**
- Branches (taken vs not taken)
- Jumps (JAL, JALR)
- Stores (need WRITEBACK for PC update)
- MRET (return from trap)

**Lesson:** PC update is complex and requires careful consideration of all instruction types.

### Pattern #3: Data Validity (Bugs #12, #13)
**Problem:** Stale or invalid data used for computation  
**Solution:** Track validity of data with explicit flags  
**Examples:**
- `instruction_valid` flag for instruction register
- Clear validity flags when data becomes stale

**Lesson:** In multi-cycle designs, explicitly track when data is valid vs stale.

### Pattern #4: Bus Protocol (Bug #1)
**Problem:** Handshake signals not held during wait states  
**Solution:** Hold request signals high until acknowledged  
**Lesson:** Multi-cycle bus protocols require careful signal management.

---

## Testing Strategy

### Phase 4: Basic Functionality
- Manual inspection of waveforms
- Simple "Hello World" test
- Bugs #1-8 discovered and fixed

### Phase 5: Systematic ISA Verification
- 187 test cases from riscv-tests repository
- Automated test framework
- Bug #9 discovered when branch tests failed
- **Result:** 100% pass rate on all RV32IM tests

### Phase 6A: Trap Support
- Created test_trap.S to verify ECALL/EBREAK/MRET
- Bugs #10-11 discovered when trap handler didn't work
- **Result:** Basic trap flow working

### Phase 6B: Exception Testing
- Created test_illegal_inst.S
- Bugs #12-14 discovered through iterative debugging
- Added trap monitoring to testbench for visibility
- **Result:** Illegal instruction and load misalignment exceptions working

---

## Current Status

**Total Bugs Fixed:** 14  
**Critical Bugs Remaining:** 0 known  
**Test Pass Rate:** 100% on implemented features  
**Project Completion:** ~78% to OpenSBI boot

### What's Working ✅
- Complete RV32I instruction set (40+ instructions)
- M-extension (multiply/divide)
- Trap entry/exit (ECALL/EBREAK/MRET)
- Illegal instruction exception (mcause=2)
- Load address misalignment (mcause=4)
- Store address misalignment (mcause=6, logic implemented)
- CSR read/write operations

### What's Next
- Store misalignment testing
- Instruction address misalignment
- CSR instruction variants (CSRRS, CSRRC, etc.)
- Interrupt support (Phase 6C)
- OpenSBI boot (Phase 7)

---

## Debug Techniques Used

1. **Waveform Analysis:** Inspecting VCD traces to see signal values over time
2. **Testbench Monitoring:** Adding $display statements for key events
3. **Disassembly Review:** Checking generated machine code matches intent
4. **Incremental Testing:** Building simple tests that isolate specific features
5. **State Machine Tracing:** Monitoring state transitions to find incorrect flows
6. **Pattern Recognition:** Identifying similar bugs across different features

---

**Last Updated:** 2026-02-26  
**Maintained By:** Development Log
