# Division Unit Bug Fix - COMPLETE

## Problem Summary
OpenSBI was stuck in an infinite loop calling `__qdivrem` (64-bit software division emulation) because the hardware 32-bit division unit was returning incorrect results.

## Root Causes Found and Fixed

### 1. **Multiple Start Pulses** (cpu_core.sv:745, 753)
**Problem**: `muldiv_start` was asserted every cycle while in STATE_EXECUTE, causing the division unit to restart repeatedly.

**Fix**: Only assert `muldiv_start` when not already busy:
```systemverilog
muldiv_start = !muldiv_done && !muldiv_busy;  // Only start once
```

### 2. **Incorrect Division Initialization** (muldiv.sv:162 - REMOVED)
**Problem**: After setting `div_working` in the case statement, line 162 immediately overwrote it with an uninitialized `div_a` value.

**Fix**: Removed the redundant assignment:
```systemverilog
// REMOVED: div_working <= {32'h0, div_a};
```

### 3. **Incorrect Subtraction in Division Loop** (muldiv.sv:210)
**Problem**: When subtracting the divisor, the code subtracted from the entire 64-bit value:
```systemverilog
div_working <= shifted - {32'h0, div_b};  // WRONG - corrupts lower 32 bits
```

This caused the lower 32 bits (the remaining dividend) to borrow from the subtraction, corrupting the result.

**Fix**: Only subtract from the upper 32 bits:
```systemverilog
div_working <= {shifted[63:32] - div_b, shifted[31:0]};  // CORRECT
```

### 4. **Spurious Remainder Update** (muldiv.sv:217 - REMOVED)
**Problem**: Inside the division loop, `div_remainder` was being updated every cycle with the shifted value before subtraction.

**Fix**: Removed line 217. The remainder is now only set once in the finalization step (line 220).

## Test Results

### Before Fix:
```
Input: 0x0003F000 / 16 (258048 / 16)
Expected: 0x3F00 (16128)
Got: 0x3FFF (16383) ❌
Error: +255 (all quotient bits set to 1 incorrectly)
```

### After Fix:
```
Input: 0x0003F000 / 16 (258048 / 16)
Expected: 0x3F00 (16128)
Got: 0x3F00 (16128) ✅
```

## OpenSBI Boot Progress

**Before fix**: Stuck at `__qdivrem` (PC 0x1b6XX), looping 100K+ times

**After fix**: Successfully passed timer initialization, now at PC 0x16018 (spin_lock)

## Next Issue: Spinlock Deadlock

OpenSBI is now stuck in a `spin_lock` wait loop at PC 0x16014-0x16024. Since this is a single-hart system, a spinlock that doesn't succeed immediately indicates either:
1. Lock management bug in OpenSBI single-hart path
2. Issue with atomic operations (AMOSWAP/AMOADD)
3. Lock was left in locked state during initialization

##Files Modified:
- `rtl/core/muldiv.sv` - Fixed division algorithm
- `rtl/core/cpu_core.sv` - Fixed muldiv_start control signal
- `sim/testbenches/tb_soc.sv` - Added HW_DIV monitoring probes (temporary)

## Performance:
- Division now completes in 33 cycles (32 algorithm cycles + 1 done state)
- No more infinite loops in `__qdivrem`
