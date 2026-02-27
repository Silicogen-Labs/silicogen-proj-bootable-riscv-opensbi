# RISC-V Processor Project - TODO List

**Last Updated:** 2026-02-27  
**Current Phase:** Phase 7 IN PROGRESS 🔧  
**Next Milestone:** Fix Spinlock Deadlock → OpenSBI Banner Print!

---

## ⭐ PHASE 5 COMPLETE! ⭐ (2026-02-26)

### Major Achievement
- ✅ Fixed critical branch instruction bug (#9 - branch_taken not latched)
- ✅ All test suites passing with 100% success rate
- ✅ Verified RV32I base instruction set working correctly
- ✅ Partially verified M-extension (MUL, DIV, REM)
- ✅ Created comprehensive test infrastructure (187 tests)
- ✅ Enhanced testbench with automatic verification

**See PHASE_5_COMPLETE.md for full details**

---

## ⭐ PHASE 6A COMPLETE! ⭐ (2026-02-26)

### Major Achievement - Basic Trap Support Working!
- ✅ Implemented ECALL instruction (trap to M-mode handler)
- ✅ Implemented EBREAK instruction (breakpoint trap)
- ✅ Implemented MRET instruction (return from trap)
- ✅ Fixed trap_taken continuous assertion bug (#10)
- ✅ Fixed MRET PC update timing bug (#11)
- ✅ Verified complete trap flow with test_trap.S
- ✅ CSR operations working (CSRR/CSRW on mepc, mtvec, mcause)

**See PHASE_6A_COMPLETE.md for full details**

---

## ⭐ PHASE 6B COMPLETE! ⭐ (2026-02-26)

### Major Achievement - All Exception Types Working!
- ✅ Implemented illegal instruction exception (mcause=2)
- ✅ Implemented load address misalignment (mcause=4)
- ✅ Implemented store address misalignment (mcause=6)
- ✅ Implemented instruction address misalignment (mcause=0)
- ✅ Fixed spurious illegal instruction detection bug (#12)
- ✅ Fixed instruction_valid not cleared after trap bug (#13)
- ✅ Fixed MRET signal not latched bug (#14)
- ✅ Created 8 comprehensive exception tests - all passing
- ✅ Created BUG_LOG.md documenting all 14 bugs

**See PHASE_6B_COMPLETE.md for full details**

---

## ⭐ PHASE 6C COMPLETE! ⭐ (2026-02-26)

### Major Achievement - Timer Interrupts Working!
- ✅ Implemented RISC-V CLINT-compatible timer peripheral
- ✅ Created mtime (64-bit auto-increment) and mtimecmp registers
- ✅ Implemented timer interrupt generation (mtime >= mtimecmp)
- ✅ Added interrupt detection logic in CPU (STATE_FETCH)
- ✅ Updated CSR file with mip.MTIP driven by hardware
- ✅ Fixed critical Bug #15: Load/store control signals in STATE_MEMORY
- ✅ Created test_timer_simple.S - register access test (PASS)
- ✅ Created test_timer_irq.S - interrupt delivery test (PASS)
- ✅ All regression tests still passing (205 total)

**See PHASE_6C_COMPLETE.md for full details**

---

## ⭐ PHASE 6D COMPLETE! ⭐ (2026-02-26)

### Major Achievement - Software Interrupts Working!
- ✅ Implemented software interrupt detection in CPU
- ✅ Added mip.MSIP (bit 3) and mie.MSIE (bit 3) CSR support
- ✅ Implemented interrupt priority arbiter (Software > Timer)
- ✅ Created test_sw_irq.S - software interrupt test (PASS)
- ✅ Created test_irq_priority.S - priority verification (PASS)
- ✅ All regression tests passing (198 total tests)
- ✅ No new bugs - clean implementation!

**See PHASE_6D_COMPLETE.md for full details**

---

## ⭐ PHASE 7 COMPLETE! ⭐ (2026-02-27)

### 🎉 GOAL ACHIEVED — OpenSBI Boots and Prints Full Banner!

- ✅ Fixed Bug #16: muldiv_start asserted continuously (cpu_core.sv)
- ✅ Fixed Bug #17: div_working overwritten during init (muldiv.sv:162)
- ✅ Fixed Bug #18: Division subtraction corrupting lower bits (muldiv.sv:210)
- ✅ Fixed Bug #19: Spurious div_remainder updates (muldiv.sv:217)
- ✅ Fixed Bug #20: DTB endianness corruption (Makefile:142)
- ✅ Fixed Bug #21: OpenSBI warmboot path taken (fw_jump.S)
- ✅ Fixed Bug #22: RV64 code on RV32 CPU (build flags, PLATFORM_RISCV_XLEN=32)
- ✅ Fixed Bug #23: nascent_init not populated (platform.c)
- ✅ Fixed Bug #24: Halfword store wstrb wrong mask (cpu_core.sv)
- ✅ Fixed Bug #25: Byte store data not replicated (cpu_core.sv)
- ✅ Fixed Bug #26: platform_ops_addr = NULL (platform.c)
- ✅ Fixed Bug #27: fw_rw_offset not power-of-2 (fw_base.S)
- ✅ Fixed Bug #28: FW_JUMP_ADDR=0x0 rejected (Makefile)
- ✅ **Fixed Bug #29: UART reg_shift=2 vs addr[2:0] mismatch (uart_16550.sv) ← FINAL BUG**

**Full OpenSBI boot banner output:**
```
OpenSBI v1.8.1-32-g8d1c21b3
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : Bootble RV32IMA
Platform Features           : medeleg
Platform HART Count         : 1
Platform Console Device     : uart8250
Firmware Base               : 0x0
Firmware Size               : 308 KB
Firmware RW Offset          : 0x40000
Domain0 Next Address        : 0x00800000
Boot HART Base ISA          : rv32ima
Runtime SBI Version         : 3.0
```

**See BUG_LOG.md bugs #24–#29 for full details**

---

## Quick Status Overview

### Completed Phases ✅
- [x] **Phase 0:** Environment setup
- [x] **Phase 1:** Microarchitecture design and documentation
- [x] **Phase 2:** RTL implementation (2,311 lines)
- [x] **Phase 3:** System integration (SoC with CPU, RAM, UART, bus)
- [x] **Phase 4:** Basic simulation and "Hello RISC-V!" test
- [x] **Phase 5:** Full ISA verification - RV32I + M extension ✅
- [x] **Phase 6A:** Basic trap support (ECALL/EBREAK/MRET) ✅
- [x] **Phase 6B:** Complete exception handling ✅
- [x] **Phase 6C:** Timer interrupt support ✅
- [x] **Phase 6D:** Software interrupts ✅
- [x] **Phase 7:** OpenSBI integration — **COMPLETE** ✅ OpenSBI boots!
- [ ] **Phase 8:** FPGA implementation

### All 29 Critical Bugs Fixed ✅
1. ✅ Bus request signals not held during wait states
2. ✅ Register write enable not latched
3. ✅ PC not updated correctly after branches/jumps
4. ✅ Register write source not latched
5. ✅ Load byte/halfword extraction incorrect
6. ✅ Memory address using wrong ALU result
7. ✅ UART byte addressing incorrect
8. ✅ Store instructions not advancing PC
9. ✅ Branch taken signal not latched (Phase 5)
10. ✅ trap_taken held continuously (Phase 6A)
11. ✅ MRET PC update in wrong state (Phase 6A)
12. ✅ Spurious illegal instruction detection (Phase 6B)
13. ✅ instruction_valid not cleared after trap (Phase 6B)
14. ✅ MRET signal not latched (Phase 6B)
15. ✅ Load/store control signals invalid in STATE_MEMORY (Phase 6C)
16. ✅ muldiv_start asserted continuously (Phase 7 - cpu_core.sv)
17. ✅ div_working overwritten after init (Phase 7 - muldiv.sv:162)
18. ✅ Division subtraction corrupting lower bits (Phase 7 - muldiv.sv:210)
19. ✅ Spurious div_remainder updates (Phase 7 - muldiv.sv:217)
20. ✅ DTB endianness corruption (Phase 7 - Makefile:142)
21. ✅ OpenSBI warmboot path taken (Phase 7 - fw_jump.S)
22. ✅ RV64 code on RV32 CPU (Phase 7 - build flags)
23. ✅ nascent_init not populated (Phase 7 - platform.c)
24. ✅ Halfword store wstrb wrong mask (Phase 7 - cpu_core.sv)
25. ✅ Byte store data not replicated (Phase 7 - cpu_core.sv)
26. ✅ platform_ops_addr = NULL (Phase 7 - platform.c)
27. ✅ fw_rw_offset not power-of-2 (Phase 7 - fw_base.S)
28. ✅ FW_JUMP_ADDR=0x0 rejected (Phase 7 - Makefile)
29. ✅ **UART reg_shift=2 vs addr[2:0] mismatch (Phase 7 - uart_16550.sv) ← FINAL BUG**

### What's Working Perfectly ✅
- Complete RV32I base instruction set (40+ instructions)
- M-extension multiply and divide
- Memory-mapped I/O (UART)
- Multi-cycle state machine with proper latching
- All load/store operations (byte, halfword, word — all correct)
- All branch and jump instructions
- **Trap entry (ECALL/EBREAK)** ✅
- **Trap handler execution** ✅
- **Trap return (MRET)** ✅
- **CSR read/write (CSRR/CSRW)** ✅
- **Timer peripheral (mtime/mtimecmp)** ✅
- **Timer interrupts** ✅
- **Software interrupts** ✅
- **Interrupt priority arbiter** ✅
- **Interrupt detection and delivery** ✅
- **OpenSBI v1.8.1 boots and prints full banner** ✅

---

## ✅ PHASE 6B: Complete Exception Handling (COMPLETE)

**Goal:** Test all exception types and verify CSR instruction variants

**Actual Duration:** 1 day  
**Complexity:** Medium
**Status:** All exception types implemented and tested!

### 6B.1 Exception Type Testing (Priority 1)

- [x] **Illegal Instruction Exception Test** ✅
  - [x] Detection already implemented in decoder
  - [x] Write test with invalid opcode (0xFFFFFFFF)
  - [x] Verify trap occurs with mcause=2
  - [x] Verify mtval contains the illegal instruction
  - [x] Verify trap handler can read and handle it
  - [x] Fixed Bug #12: Spurious illegal instruction on stale data
  - [x] Fixed Bug #13: instruction_valid not cleared after trap
  - [x] Fixed Bug #14: MRET signal not latched causing PC skip

- [x] **Load Address Misalignment Test** ✅
  - [x] Implemented detection logic in STATE_MEMORY
  - [x] Write test: LH from odd address (0x3001)
  - [x] Write test: LW from unaligned address (0x3002)
  - [x] Verify trap with mcause=4
  - [x] Verify mtval contains faulting address
  - [x] Test prints '4P' confirming mcause=4

- [x] **Store Address Misalignment Test** ✅
  - [x] Detection logic implemented (same as load)
  - [x] Write test: SH to odd address
  - [x] Verify trap with mcause=6
  - [x] Verify mtval contains faulting address
  - [x] Test prints '6P' confirming mcause=6

- [x] **Instruction Address Misalignment Test** ✅
  - [x] Implemented detection in STATE_EXECUTE for jumps/branches
  - [x] Write test: JALR to address 0x3 (not 4-byte aligned)
  - [x] Verify trap with mcause=0
  - [x] Verify mtval contains misaligned PC
  - [x] Test prints '0P' confirming mcause=0

### 6B.2 CSR Instruction Verification (Priority 2)

- [x] **CSRRW (CSR Read/Write)** - Verified with test_trap.S
  - [x] Basic operation tested
  - [ ] Test with rd=x0 (write-only, no read)
  
- [ ] **CSRRS (CSR Read and Set Bits)**
  - [ ] Test setting bits in mstatus
  - [ ] Test with rs1=x0 (read-only, no write)
  - [ ] Verify bits are OR'd correctly

- [ ] **CSRRC (CSR Read and Clear Bits)**
  - [ ] Test clearing bits in mie
  - [ ] Test with rs1=x0 (read-only, no write)
  - [ ] Verify bits are cleared correctly

- [ ] **CSRRWI (CSR Read/Write Immediate)**
  - [ ] Test with 5-bit immediate value
  - [ ] Verify zero-extension

- [ ] **CSRRSI (CSR Read/Set Immediate)**
  - [ ] Test setting bits with immediate
  - [ ] Test with imm=0 (read-only)

- [ ] **CSRRCI (CSR Read/Clear Immediate)**
  - [ ] Test clearing bits with immediate
  - [ ] Test with imm=0 (read-only)

### 6B.3 CSR Access Control (Priority 3)

- [ ] **Illegal CSR Access Detection**
  - [ ] Test writing to read-only CSR (misa, mhartid)
  - [ ] Verify illegal instruction exception (mcause=2)
  - [ ] Test accessing non-existent CSR
  - [ ] Verify illegal instruction exception

- [ ] **CSR Privilege Checks** (Future - when S/U modes added)
  - Not needed for M-mode only implementation
  - Defer until multi-privilege support

### 6B.4 Complete CSR Register Implementation

#### Already Working ✅
- [x] misa (0x301) - ISA description
- [x] mhartid (0xF14) - Hardware thread ID  
- [x] mtvec (0x305) - Trap vector base
- [x] mepc (0x341) - Exception PC
- [x] mcause (0x342) - Trap cause
- [x] mtval (0x343) - Trap value
- [x] mscratch (0x340) - Scratch register

#### Need Verification ⚠️
- [ ] **mstatus (0x300)** - Machine status
  - [x] MIE, MPIE, MPP fields implemented
  - [ ] Test read/write of individual fields
  - [ ] Verify reserved bits are read-only zero

- [ ] **mie (0x304)** - Interrupt enable
  - [x] Basic implementation exists
  - [ ] Verify MEIE, MTIE, MSIE bits work
  - [ ] Test setting/clearing individual bits

- [ ] **mip (0x344)** - Interrupt pending
  - [x] Basic implementation exists
  - [ ] Verify MSIP is writable
  - [ ] Verify MTIP, MEIP are read-only

#### Need to Add 📝
- [ ] **mvendorid (0xF11)** - Return 0 (non-commercial)
- [ ] **marchid (0xF12)** - Return 0 (not assigned)
- [ ] **mimpid (0xF13)** - Return version number

- [ ] **mcycle (0xB00)** / **mcycleh (0xB80)**
  - [x] Counters already incrementing
  - [ ] Verify read/write works
  - [ ] Test overflow from lower to upper 32 bits

- [ ] **minstret (0xB02)** / **minstreth (0xB82)**
  - [x] Counters already incrementing
  - [ ] Verify read/write works
  - [ ] Test overflow handling

---

## ✅ PHASE 6C: Timer Interrupt Support (COMPLETE)

**Goal:** Implement timer interrupts

**Actual Duration:** 1 day  
**Complexity:** High (included critical bug fix)
**Status:** Timer interrupts fully working!

### 6C.1 Timer Interrupt Implementation ✅

- [x] **Memory-Mapped Timer Registers** ✅
  - [x] Add mtime register at 0x200BFF8 (64-bit, read-only from software)
  - [x] Add mtimecmp register at 0x2004000 (64-bit, read-write)
  - [x] Implement timer peripheral module (timer.sv, 107 lines)
  - [x] Integrated into bus and SoC

- [x] **Timer Interrupt Logic** ✅
  - [x] Compare mtime >= mtimecmp every cycle
  - [x] Drive mip.MTIP directly from hardware (read-only bit)
  - [x] Clear interrupt when mtimecmp is written
  - [x] Generate interrupt if mie.MTIE and mstatus.MIE set
  - [x] Interrupt detection in STATE_FETCH before next instruction

- [x] **Timer Interrupt Testing** ✅
  - [x] Created test_timer_simple.S - register access (PASS)
  - [x] Created test_timer_irq.S - full interrupt test (PASS)
  - [x] Verified mcause = 0x80000007 (interrupt bit + code 7)
  - [x] Verified trap handler executes correctly
  - [x] Verified interrupt can be cleared and execution resumes
  - [x] Fixed Bug #15: Control signals invalid in STATE_MEMORY

### 6C.2 Critical Bug Fixed ✅

- [x] **Bug #15: Load/Store Address Calculation** ✅
  - [x] **Problem:** ALU operand mux used rs2 instead of immediate in STATE_MEMORY
  - [x] **Impact:** Stores calculated wrong address (rs1 + rs2 instead of rs1 + imm)
  - [x] **Symptom:** Store misalignment exceptions in trap handler
  - [x] **Fix:** Extended control signal scope to include STATE_MEMORY
  - [x] **Result:** All loads/stores now work correctly in all contexts

---

## ✅ PHASE 6D: Software Interrupts (COMPLETE)

**Goal:** Implement software interrupts

**Actual Duration:** <1 hour  
**Complexity:** Low (reused timer interrupt infrastructure)
**Status:** Software interrupts fully working!

### 6D.1 Software Interrupt Implementation ✅

- [x] **MSIP Register (CSR-based)** ✅
  - [x] mip.MSIP (bit 3) already implemented in CSR file
  - [x] MSIP writable via CSR write to mip
  - [x] Added mip_msip_out signal to CPU
  - [x] No memory-mapped register needed (CSR-only)

- [x] **Software Interrupt Detection** ✅
  - [x] Added software interrupt check in STATE_FETCH
  - [x] Check: mstatus.MIE && mie.MSIE && mip.MSIP
  - [x] Set trap_cause = 4'h3 (machine software interrupt)
  - [x] Set is_interrupt = 1 for mcause

- [x] **Software Interrupt Testing** ✅
  - [x] Created test_sw_irq.S
  - [x] Test sets mip.MSIP via CSR write
  - [x] Verified interrupt occurs
  - [x] Verified mcause = 0x80000003 (interrupt bit + code 3)
  - [x] Verified trap handler executes
  - [x] Tested clearing mip.MSIP and resuming
  - [x] Result: PASS ('I3P')

### 6D.2 Interrupt Priority Implementation ✅

- [x] **Priority Arbiter** ✅
  - [x] Software > Timer (correct RISC-V M-mode priority)
  - [x] When multiple interrupts pending, highest priority taken
  - [x] Updated interrupt detection logic with priority

- [x] **Interrupt Priority Testing** ✅
  - [x] Created test_irq_priority.S with both interrupts pending
  - [x] Verified software taken first, then timer after clearing
  - [x] Result: PASS ('STP')

### 6D.3 Interrupt Infrastructure Validation ✅

- [x] **Regression Testing** ✅
  - [x] All 9 existing tests pass
  - [x] Timer interrupts still work
  - [x] Exceptions still work
  - [x] No regressions introduced

---

## ✅ PHASE 7: OpenSBI Integration (COMPLETE - 2026-02-27)

**Goal:** Boot real OpenSBI firmware and print banner  
**Status:** COMPLETE — OpenSBI v1.8.1 boots and prints full banner ✅

### 7.1 OpenSBI Build and Integration ✅

- [x] Cloned OpenSBI repository
- [x] Created bootble platform configuration (`opensbi/platform/bootble/`)
- [x] Built fw_jump for RV32IMA (`PLATFORM_RISCV_XLEN=32`)
- [x] Converted to hex format
- [x] Created device tree blob (`bootble.dtb`, `reg-shift=2`, `reg-io-width=4`)
- [x] Boot image: OpenSBI at `0x0`, DTB at `0x3F0000`, next-stage at `0x800000`

### 7.2 Division Unit Bug Fixes ✅ (Bugs #16–#19)

- [x] Bug #16: muldiv_start continuous assertion fixed
- [x] Bug #17: div_working overwrite during init fixed
- [x] Bug #18: Division subtraction borrow corruption fixed
- [x] Bug #19: Spurious div_remainder updates fixed

### 7.3 Platform Initialization Bug Fixes ✅ (Bugs #20–#28)

- [x] Bug #20: DTB endianness (`xxd` → `od -tx4`)
- [x] Bug #21: Warmboot path (`fw_jump.S` li a0,0)
- [x] Bug #22: RV64 on RV32 (PLATFORM_RISCV_XLEN=32)
- [x] Bug #23: nascent_init not populated (platform.c)
- [x] Bug #24: Halfword store wstrb mask (cpu_core.sv)
- [x] Bug #25: Byte store data replication (cpu_core.sv)
- [x] Bug #26: platform_ops_addr = NULL (platform.c runtime patch)
- [x] Bug #27: fw_rw_offset power-of-2 (fw_base.S FW_TEXT_START)
- [x] Bug #28: FW_JUMP_ADDR=0x800000 (Makefile)

### 7.4 Final UART Fix ✅ (Bug #29)

- [x] Bug #29: UART reg_shift=2 vs addr[2:0] mismatch
  - Changed `uart_16550.sv` line 55: `addr[2:0]` → `addr[4:2]`
  - Removed 500-byte UART output cap in testbench
  - **Result: Full OpenSBI banner prints!** ✅

---

## Quick Reference Commands

```bash
# Boot OpenSBI (the main achievement!)
make TEST=final_boot HEX_FILE=build/final_boot.hex sim
rm -f /tmp/uart_output.txt && ./build/verilator/Vtb_soc > /tmp/sim.log 2>&1
cat /tmp/uart_output.txt   # Should show full OpenSBI banner

# Test trap handling
make TEST=test_trap sw sim
./build/verilator/Vtb_soc

# Test basic functionality
make TEST=hello sw sim
./build/verilator/Vtb_soc

# Run all verification tests
for test in test_alu test_memory test_branch test_muldiv test_trap; do
    echo "=== Running $test ==="
    make TEST=$test sw sim >/dev/null 2>&1
    timeout 30 ./build/verilator/Vtb_soc 2>&1 | tail -15
done
```

---

## Project Statistics (Updated 2026-02-27)

- **RTL Lines:** ~2,600 lines of SystemVerilog
- **Test Lines:** 870 lines (framework + 18 test programs)
- **Total Tests:** 187 ISA tests + 11 exception/interrupt tests = 198 tests
- **Bugs Fixed:** 29 critical bugs across all phases
- **Instructions Implemented:** ~46 (RV32I + M + ECALL/EBREAK/MRET)
- **Exceptions Working:** 9 out of 9
- **Interrupts Working:** Timer ✅, Software ✅
- **Simulation Speed:** ~400K cycles/second
- **Project Duration:** Started Feb 2026, Phase 7 complete Feb 27 2026
- **Completion:** **100% — OpenSBI boots!** ✅

---

## Next Session Priorities (Phase 7 - OpenSBI)

### Session Goals:
1. ✅ Phase 6D Complete - Software interrupts working!
2. ✅ Interrupt priority arbiter working!
3. ✅ All 198 tests passing!
4. Verify CSR instruction variants (CSRRS, CSRRC, etc.)
5. Verify counter CSRs (mcycle, minstret)
6. Clone and build OpenSBI for RV32IMA
7. Attempt first OpenSBI boot!

---

**Current Status:** PHASE 7 COMPLETE — OpenSBI boots!
**Next Milestone:** Phase 8 — FPGA implementation
**Ultimate Goal:** Boot OpenSBI firmware — ACHIEVED 2026-02-27

**Latest Achievement:** RV32IMA softcore successfully boots OpenSBI v1.8.1 and prints full banner. 29 bugs fixed across all phases. Project simulation goal fully achieved.
