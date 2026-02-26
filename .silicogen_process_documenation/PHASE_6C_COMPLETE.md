# Phase 6C Complete: Timer Interrupts

**Date:** 2026-02-26  
**Status:** ✅ COMPLETE  
**Result:** Timer interrupts fully functional with hardware timer peripheral

---

## Summary

Implemented complete timer interrupt support including:
- RISC-V standard timer peripheral (mtime/mtimecmp)
- Timer interrupt detection and delivery to CPU
- CSR updates for interrupt enable (mie) and pending (mip) registers
- Comprehensive testing of timer interrupt functionality

**Key Achievement:** First asynchronous interrupt working! The CPU can now be interrupted by external hardware events.

---

## Components Implemented

### 1. Timer Peripheral (`rtl/peripherals/timer.sv`)
**Created:** New 107-line module implementing RISC-V CLINT timer

**Features:**
- 64-bit `mtime` register - auto-increments every clock cycle
- 64-bit `mtimecmp` register - programmable compare value
- Memory-mapped at standard RISC-V addresses:
  - `0x0200BFF8`: mtime low word (read-only)
  - `0x0200BFFC`: mtime high word (read-only)
  - `0x02004000`: mtimecmp low word (read/write)
  - `0x02004004`: mtimecmp high word (read/write)
- `timer_irq` output: HIGH when `mtime >= mtimecmp`
- Writing to mtimecmp clears the interrupt

**Design Choice:** Used standard RISC-V CLINT addresses to ensure OpenSBI compatibility.

### 2. Bus Updates (`rtl/bus/simple_bus.sv`)
**Modified:** Added timer routing

**Changes:**
- Added timer slave interface (req, we, addr, wdata, wstrb, rdata, ready)
- Address decode for timer region: `0x02000000 - 0x02FFFFFF`
- Updated instruction/data bus routing muxes
- Response path routing for timer reads

**Lines Added:** ~40 lines

### 3. SoC Integration (`rtl/soc/riscv_soc.sv`)
**Modified:** Instantiated timer and wired to CPU

**Changes:**
- Added timer interface signals
- Instantiated timer peripheral
- Connected timer_irq to CPU core
- Connected timer to bus arbiter
- Updated memory map documentation

**Lines Added:** ~25 lines

### 4. CPU Core Updates (`rtl/core/cpu_core.sv`)
**Modified:** Added interrupt detection logic

**Changes:**
- Added `timer_irq` input port
- Added `mstatus_mie` and `mie_mtie` outputs from CSR
- Interrupt detection in STATE_FETCH:
  ```systemverilog
  if (state == STATE_FETCH && mstatus_mie && mie_mtie && timer_irq) begin
      trap_detected = 1'b1;
      trap_cause = 4'h7;        // Machine timer interrupt
      is_interrupt = 1'b1;       // Set interrupt bit for mcause
  ```
- **BUG FIX #15:** Extended control signal validity to STATE_MEMORY
  - Changed `if (state == STATE_DECODE || state == STATE_EXECUTE)`
  - To: `if (state == STATE_DECODE || state == STATE_EXECUTE || state == STATE_MEMORY)`
  - Ensures load/store address calculation works correctly in STATE_MEMORY

**Lines Modified:** ~15 lines  
**Critical Fix:** 1 line change that fixed address calculation in STATE_MEMORY

### 5. CSR File Updates (`rtl/core/csr_file.sv`)
**Modified:** Added interrupt support

**Changes:**
- Added `timer_irq` input
- Added `mstatus_mie_out` and `mie_mtie_out` outputs
- Updated `mip` register:
  ```systemverilog
  mip[3] = mip_msip;    // Software interrupt (writable)
  mip[7] = timer_irq;   // Timer interrupt (read-only, hardware-driven)
  ```
- mie register already supported MTIE (bit 7) and MSIE (bit 3)
- mcause correctly sets bit 31 for interrupts: `{1'b1, 27'h0, trap_cause}`

**Lines Added:** ~15 lines

### 6. Test Programs

#### `sw/tests/test_timer_simple.S` ✅
Simple test to verify timer register access works.
- Writes value to mtimecmp
- Reads back and compares
- **Result:** PASS ('P')

#### `sw/tests/test_timer_irq.S` ✅
Comprehensive timer interrupt test.
- Sets up trap handler
- Enables global interrupts (mstatus.MIE)
- Enables timer interrupt (mie.MTIE)
- Sets mtimecmp to small value (100 cycles)
- Waits in loop for interrupt
- Trap handler verifies mcause = 0x80000007
- Clears interrupt by setting mtimecmp to max
- **Result:** PASS ('I7P' - Interrupt, code 7, Pass)

---

## Bug Fixed

### **Bug #15: Load/Store Address Calculation in STATE_MEMORY**

**Symptom:**
- Timer interrupt test failed with store misalignment exception (mcause 6)
- Only occurred when executing stores INSIDE trap handler
- Same store instructions worked fine in normal code
- Address 0x02004000 (correctly aligned) reported as misaligned

**Root Cause:**
Control signals (`alu_src_a`, `alu_src_b`, etc.) were only set when:
```systemverilog
if (state == STATE_DECODE || state == STATE_EXECUTE)
```

But load/store address calculation happens in STATE_MEMORY! In STATE_MEMORY, signals reverted to defaults:
- `alu_src_a = 2'b00` (rs1) ← Correct
- `alu_src_b = 2'b00` (rs2) ← **WRONG! Should be immediate!**

For `sw s1, 0(s0)`:
- **Expected:** Address = s0 + 0 = 0x02004000 (aligned)
- **Actual:** Address = s0 + s1 = 0x02004000 + 0xFFFFFFFF = 0x02003FFF (misaligned!)

**Fix:**
Extended control signal scope to include STATE_MEMORY:
```systemverilog
if (state == STATE_DECODE || state == STATE_EXECUTE || state == STATE_MEMORY)
```

**Impact:**
- **Critical bug** - affected ALL load/store instructions in certain conditions
- Only manifested when:
  1. Load/store followed instructions that used different ALU sources
  2. In trap handlers where rs2 might contain non-zero values
- Bug present since initial load/store implementation but masked by test patterns

**Lesson Learned:**
When combinational control signals affect multiple pipeline stages, ensure they're valid in ALL relevant states, not just where instructions are decoded.

**File:** `rtl/core/cpu_core.sv:569`  
**Change:** 1 line modified  
**Severity:** High (affects correctness)  
**Detection:** Debug-intensive - required understanding ALU operand selection timing

---

## Testing Results

### Regression Tests - All Pass ✅
```
test_trap:           'OK'  - Basic ECALL/EBREAK/MRET
test_illegal_simple: '2'   - Illegal instruction (mcause 2)
test_misalign_simple:'4'   - Load misalignment (mcause 4)
test_store_simple:   '6'   - Store misalignment (mcause 6)
test_pc_simple:      '0'   - PC misalignment (mcause 0)
test_timer_simple:   'P'   - Timer register access
test_timer_irq:      'I7P' - Timer interrupt (mcause 0x80000007)
```

**Total Exception/Interrupt Tests:** 7 (all passing)  
**Exception Types Tested:** 6 (mcause 0,2,3,4,6,11)  
**Interrupt Types Tested:** 1 (mcause 0x80000007 - timer)

### Test Coverage
- ✅ Timer register read/write
- ✅ Timer interrupt generation (mtime >= mtimecmp)
- ✅ Interrupt detection in CPU
- ✅ mcause bit 31 set correctly for interrupts
- ✅ mcause exception code correct (7 for timer)
- ✅ Interrupt enable checking (mstatus.MIE && mie.MTIE)
- ✅ Interrupt delivery to trap handler
- ✅ Interrupt clearing by writing mtimecmp
- ✅ Correct operation after interrupt return

---

## Architecture Details

### Interrupt Handling Flow

1. **Interrupt Generation:**
   - Timer increments mtime every cycle
   - When mtime >= mtimecmp, timer_irq goes HIGH
   - timer_irq drives mip.MTIP (CSR bit, read-only)

2. **Interrupt Detection (STATE_FETCH):**
   - Before fetching next instruction, check:
     - `mstatus.MIE == 1` (global interrupt enable)
     - `mie.MTIE == 1` (timer interrupt enable)
     - `timer_irq == 1` (interrupt pending)
   - If all true, set trap_detected, trap_cause=7, is_interrupt=1

3. **Trap Entry (STATE_TRAP):**
   - Save PC to mepc
   - Set mcause = 0x80000007 (bit 31 + code 7)
   - Save mstatus.MIE to mstatus.MPIE
   - Clear mstatus.MIE (disable interrupts in handler)
   - Jump to mtvec address

4. **Interrupt Handler:**
   - Software reads mcause to determine interrupt type
   - Clear interrupt source (write mtimecmp)
   - Perform interrupt-specific handling
   - Execute MRET to return

5. **MRET Return:**
   - Restore PC from mepc
   - Restore mstatus.MIE from mstatus.MPIE
   - Resume interrupted code

### Memory Map (Updated)
```
0x00000000 - 0x003FFFFF: RAM (4MB)
0x02000000 - 0x02FFFFFF: Timer (CLINT)
  0x0200BFF8: mtime low
  0x0200BFFC: mtime high
  0x02004000: mtimecmp low
  0x02004004: mtimecmp high
0x10000000 - 0x100000FF: UART (256 bytes)
```

---

## Code Statistics

### RTL Changes
- **Files Modified:** 5
- **Files Created:** 1 (timer.sv)
- **Lines Added:** ~200 lines
- **Lines Modified:** ~5 lines
- **Critical Fixes:** 1

### Test Files
- **Tests Created:** 2 (test_timer_simple.S, test_timer_irq.S)
- **Test Lines:** ~100 lines

### Project Totals (After Phase 6C)
- **RTL Lines:** ~2,550 lines (+170)
- **Test Files:** 9 exception/interrupt tests
- **Passing Tests:** 196 ISA tests + 9 custom tests = 205 total
- **Bugs Fixed:** 15 total (including Bug #15)

---

## Remaining Work for Full Interrupt Support

### Phase 6D: Software Interrupts (Next)
- Add MSIP register (machine software interrupt pending)
- Allow software to trigger interrupts via CSR write
- Test software interrupt delivery
- **Estimated:** 1-2 hours

### Phase 6E: External Interrupts (Future)
- Add external interrupt input
- Implement MEIP (machine external interrupt pending)
- **Estimated:** 1-2 hours

### Phase 7: OpenSBI Boot (Goal)
After all interrupt types working:
- Load OpenSBI firmware
- Boot to supervisor mode
- Run OpenSBI tests
- **Estimated:** 4-8 hours

---

## Key Achievements

1. **✅ First Asynchronous Interrupt:** Timer can interrupt CPU at any time
2. **✅ Hardware Timer Working:** 64-bit timer with compare functionality
3. **✅ CSR Interrupt Support:** mie/mip registers correctly implemented
4. **✅ Interrupt Prioritization:** Checked before instruction fetch
5. **✅ Critical Bug Fixed:** Bug #15 (STATE_MEMORY control signals)
6. **✅ All Tests Pass:** No regressions, all 205 tests passing

---

## What's Next?

### Immediate (Phase 6D - Software Interrupts):
1. Add MSIP register write functionality
2. Add software interrupt detection (similar to timer)
3. Create test_sw_irq.S
4. Verify software interrupt delivery

### Medium Term (Phase 7 - OpenSBI):
1. Implement remaining CSRs needed by OpenSBI
2. Add PMP (Physical Memory Protection) if needed
3. Load and run OpenSBI firmware
4. Debug boot process

### Long Term:
1. Supervisor mode support
2. Virtual memory (satp, page tables)
3. User mode
4. Full Linux boot

---

## Lessons Learned

1. **Pipeline Timing is Critical:**
   - Control signals must be valid in ALL states where they're used
   - Not just where they're "logically" needed

2. **Debug Incrementally:**
   - test_timer_simple.S (register access) before test_timer_irq.S
   - Isolate hardware from interrupt handling
   - Add debug prints strategically

3. **Understand Data Flow:**
   - Bug #15 required deep understanding of:
     - When ALU operands are selected (STATE_MEMORY)
     - How combinational signals propagate
     - Pipeline stage boundaries

4. **Test Different Contexts:**
   - Same instruction can behave differently in:
     - Normal code
     - Trap handlers
     - After interrupts
   - Always test edge cases

---

## Files Modified

### RTL Files
- `rtl/peripherals/timer.sv` (NEW)
- `rtl/bus/simple_bus.sv`
- `rtl/soc/riscv_soc.sv`
- `rtl/core/cpu_core.sv` ⭐ (Bug #15 fix)
- `rtl/core/csr_file.sv`

### Test Files
- `sw/tests/test_timer_simple.S` (NEW)
- `sw/tests/test_timer_irq.S` (NEW)

### Documentation
- `.silicogen_process_documenation/PHASE_6C_COMPLETE.md` (this file)
- `.silicogen_process_documenation/BUG_LOG.md` (updated with Bug #15)
- `.silicogen_process_documenation/TODO.md` (updated)

---

## Conclusion

**Phase 6C is COMPLETE!** ✅

Timer interrupts are fully functional. The CPU can now:
- Be interrupted asynchronously by hardware
- Save state and jump to trap handler
- Handle interrupt in software
- Clear interrupt and resume execution

**Critical Achievement:** Bug #15 was a subtle but serious issue affecting all load/store address calculations in certain pipeline states. Finding and fixing it improves the overall robustness of the memory access path.

**Next Milestone:** Software interrupts (Phase 6D), then OpenSBI boot!

**Progress:** ~85% to OpenSBI boot  
**Estimated Remaining:** 8-12 hours

**Status:** Ready for Phase 6D - Software Interrupts! 🚀
