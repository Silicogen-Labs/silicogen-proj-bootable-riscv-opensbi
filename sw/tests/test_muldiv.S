# RISC-V M-Extension Test Suite
#
# Tests all multiply and divide instructions
# MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
# Uses test framework for self-checking results

.include "test_framework.h"

.section .text
.globl _start

_start:
    # Initialize test framework
    TEST_INIT
    
    # Set up stack pointer
    lui sp, %hi(0x00400000)
    addi sp, sp, %lo(0x00400000)
    
    # Run all test groups
    call test_mul
    call test_mulh
    call test_mulhsu
    call test_mulhu
    call test_div
    call test_divu
    call test_rem
    call test_remu
    
    # Mark test complete and halt
    TEST_DONE
    TEST_HALT

# =============================================================================
# MUL - Multiply (lower 32 bits)
# =============================================================================
test_mul:
    # Test ID 0: MUL basic positive
    li a0, 10
    li a1, 20
    mul a2, a0, a1
    li a3, 200
    CHECK_EQUAL a2, a3, 0
    
    # Test ID 1: MUL with zero
    li a0, 100
    li a1, 0
    mul a2, a0, a1
    CHECK_ZERO a2, 1
    
    # Test ID 2: MUL with one
    li a0, 42
    li a1, 1
    mul a2, a0, a1
    CHECK_EQUAL a2, a0, 2
    
    # Test ID 3: MUL negative × positive
    li a0, -5
    li a1, 10
    mul a2, a0, a1
    li a3, -50
    CHECK_EQUAL a2, a3, 3
    
    # Test ID 4: MUL negative × negative
    li a0, -6
    li a1, -7
    mul a2, a0, a1
    li a3, 42
    CHECK_EQUAL a2, a3, 4
    
    # Test ID 5: MUL large values (check lower 32 bits)
    li a0, 0x10000
    li a1, 0x10000
    mul a2, a0, a1
    li a3, 0x00000000           # 0x100000000, lower 32 bits = 0
    CHECK_EQUAL a2, a3, 5
    
    # Test ID 6: MUL overflow example
    li a0, 0xFFFFFFFF           # -1 or max unsigned
    li a1, 2
    mul a2, a0, a1
    li a3, 0xFFFFFFFE           # -2 or (max*2 & 0xFFFFFFFF)
    CHECK_EQUAL a2, a3, 6
    
    # Test ID 7: MUL power of two
    li a0, 123
    li a1, 8
    mul a2, a0, a1
    li a3, 984
    CHECK_EQUAL a2, a3, 7
    
    ret

# =============================================================================
# MULH - Multiply High (signed × signed)
# =============================================================================
test_mulh:
    # Test ID 10: MULH basic (result fits in 32 bits - high part 0)
    li a0, 10
    li a1, 20
    mulh a2, a0, a1
    CHECK_ZERO a2, 10           # 200 fits in 32 bits, high = 0
    
    # Test ID 11: MULH large positive × positive
    li a0, 0x10000
    li a1, 0x10000
    mulh a2, a0, a1
    li a3, 1                    # 0x10000 * 0x10000 = 0x100000000
    CHECK_EQUAL a2, a3, 11      # High 32 bits = 1
    
    # Test ID 12: MULH negative × positive
    li a0, -1
    li a1, 0x10000
    mulh a2, a0, a1
    li a3, -1                   # Result is negative
    CHECK_EQUAL a2, a3, 12
    
    # Test ID 13: MULH negative × negative
    li a0, -2
    li a1, -2
    mulh a2, a0, a1
    CHECK_ZERO a2, 13           # 4, high part = 0
    
    # Test ID 14: MULH max positive
    li a0, 0x7FFFFFFF
    li a1, 2
    mulh a2, a0, a1
    CHECK_ZERO a2, 14           # Result < 2^32, high = 0
    
    # Test ID 15: MULH max negative
    li a0, 0x80000000           # Min int (-2147483648)
    li a1, 2
    mulh a2, a0, a1
    li a3, -1                   # Negative result
    CHECK_EQUAL a2, a3, 15
    
    ret

# =============================================================================
# MULHSU - Multiply High (signed × unsigned)
# =============================================================================
test_mulhsu:
    # Test ID 20: MULHSU positive signed × unsigned
    li a0, 0x10000              # Positive
    li a1, 0x10000
    mulhsu a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 20
    
    # Test ID 21: MULHSU negative signed × unsigned
    li a0, -1                   # Signed negative
    li a1, 1                    # Unsigned positive
    mulhsu a2, a0, a1
    li a3, -1                   # High part negative
    CHECK_EQUAL a2, a3, 21
    
    # Test ID 22: MULHSU with large unsigned
    li a0, 2
    li a1, 0x80000000           # Large unsigned value
    mulhsu a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 22
    
    # Test ID 23: MULHSU zero
    li a0, -1
    li a1, 0
    mulhsu a2, a0, a1
    CHECK_ZERO a2, 23
    
    ret

# =============================================================================
# MULHU - Multiply High (unsigned × unsigned)
# =============================================================================
test_mulhu:
    # Test ID 25: MULHU basic
    li a0, 0x10000
    li a1, 0x10000
    mulhu a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 25
    
    # Test ID 26: MULHU small values
    li a0, 10
    li a1, 20
    mulhu a2, a0, a1
    CHECK_ZERO a2, 26
    
    # Test ID 27: MULHU large × large
    li a0, 0xFFFFFFFF
    li a1, 0xFFFFFFFF
    mulhu a2, a0, a1
    li a3, 0xFFFFFFFE           # (2^32-1)^2 high bits
    CHECK_EQUAL a2, a3, 27
    
    # Test ID 28: MULHU with zero
    li a0, 0xFFFFFFFF
    li a1, 0
    mulhu a2, a0, a1
    CHECK_ZERO a2, 28
    
    # Test ID 29: MULHU power of 2
    li a0, 0x80000000
    li a1, 2
    mulhu a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 29
    
    ret

# =============================================================================
# DIV - Divide (signed)
# =============================================================================
test_div:
    # Test ID 30: DIV basic
    li a0, 100
    li a1, 10
    div a2, a0, a1
    li a3, 10
    CHECK_EQUAL a2, a3, 30
    
    # Test ID 31: DIV with remainder (truncates toward zero)
    li a0, 100
    li a1, 3
    div a2, a0, a1
    li a3, 33
    CHECK_EQUAL a2, a3, 31
    
    # Test ID 32: DIV negative dividend
    li a0, -100
    li a1, 10
    div a2, a0, a1
    li a3, -10
    CHECK_EQUAL a2, a3, 32
    
    # Test ID 33: DIV negative divisor
    li a0, 100
    li a1, -10
    div a2, a0, a1
    li a3, -10
    CHECK_EQUAL a2, a3, 33
    
    # Test ID 34: DIV both negative
    li a0, -100
    li a1, -10
    div a2, a0, a1
    li a3, 10
    CHECK_EQUAL a2, a3, 34
    
    # Test ID 35: DIV by zero (returns -1 per RISC-V spec)
    li a0, 100
    li a1, 0
    div a2, a0, a1
    li a3, -1
    CHECK_EQUAL a2, a3, 35
    
    # Test ID 36: DIV overflow (MIN_INT / -1, returns MIN_INT per spec)
    li a0, 0x80000000           # -2147483648
    li a1, -1
    div a2, a0, a1
    li a3, 0x80000000
    CHECK_EQUAL a2, a3, 36
    
    # Test ID 37: DIV by one
    li a0, 42
    li a1, 1
    div a2, a0, a1
    CHECK_EQUAL a2, a0, 37
    
    # Test ID 38: DIV smaller / larger (result 0)
    li a0, 5
    li a1, 10
    div a2, a0, a1
    CHECK_ZERO a2, 38
    
    ret

# =============================================================================
# DIVU - Divide (unsigned)
# =============================================================================
test_divu:
    # Test ID 40: DIVU basic
    li a0, 100
    li a1, 10
    divu a2, a0, a1
    li a3, 10
    CHECK_EQUAL a2, a3, 40
    
    # Test ID 41: DIVU with remainder
    li a0, 100
    li a1, 3
    divu a2, a0, a1
    li a3, 33
    CHECK_EQUAL a2, a3, 41
    
    # Test ID 42: DIVU large unsigned
    li a0, 0xFFFFFFFF           # Max unsigned
    li a1, 2
    divu a2, a0, a1
    li a3, 0x7FFFFFFF
    CHECK_EQUAL a2, a3, 42
    
    # Test ID 43: DIVU by zero (returns max value per spec)
    li a0, 100
    li a1, 0
    divu a2, a0, a1
    li a3, 0xFFFFFFFF
    CHECK_EQUAL a2, a3, 43
    
    # Test ID 44: DIVU smaller / larger
    li a0, 5
    li a1, 10
    divu a2, a0, a1
    CHECK_ZERO a2, 44
    
    ret

# =============================================================================
# REM - Remainder (signed)
# =============================================================================
test_rem:
    # Test ID 45: REM basic
    li a0, 100
    li a1, 10
    rem a2, a0, a1
    CHECK_ZERO a2, 45
    
    # Test ID 46: REM with remainder
    li a0, 100
    li a1, 3
    rem a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 46
    
    # Test ID 47: REM negative dividend
    li a0, -100
    li a1, 3
    rem a2, a0, a1
    li a3, -1                   # Sign follows dividend
    CHECK_EQUAL a2, a3, 47
    
    # Test ID 48: REM negative divisor
    li a0, 100
    li a1, -3
    rem a2, a0, a1
    li a3, 1                    # Sign follows dividend
    CHECK_EQUAL a2, a3, 48
    
    # Test ID 49: REM both negative
    li a0, -100
    li a1, -3
    rem a2, a0, a1
    li a3, -1
    CHECK_EQUAL a2, a3, 49
    
    # Test ID 50: REM by zero (returns dividend per spec)
    li a0, 100
    li a1, 0
    rem a2, a0, a1
    CHECK_EQUAL a2, a0, 50
    
    # Test ID 51: REM overflow case (MIN_INT % -1 = 0)
    li a0, 0x80000000
    li a1, -1
    rem a2, a0, a1
    CHECK_ZERO a2, 51
    
    ret

# =============================================================================
# REMU - Remainder (unsigned)
# =============================================================================
test_remu:
    # Test ID 52: REMU basic
    li a0, 100
    li a1, 10
    remu a2, a0, a1
    CHECK_ZERO a2, 52
    
    # Test ID 53: REMU with remainder
    li a0, 100
    li a1, 3
    remu a2, a0, a1
    li a3, 1
    CHECK_EQUAL a2, a3, 53
    
    # Test ID 54: REMU large unsigned
    li a0, 0xFFFFFFFF
    li a1, 100
    remu a2, a0, a1
    li a3, 95                   # 0xFFFFFFFF % 100 = 95
    CHECK_EQUAL a2, a3, 54
    
    # Test ID 55: REMU by zero (returns dividend per spec)
    li a0, 100
    li a1, 0
    remu a2, a0, a1
    CHECK_EQUAL a2, a0, 55
    
    # Test ID 56: REMU smaller / larger
    li a0, 5
    li a1, 10
    remu a2, a0, a1
    li a3, 5
    CHECK_EQUAL a2, a3, 56
    
    ret

# =============================================================================
# Data Section
# =============================================================================
.section .data
.align 4

test_data:
    .word 0xDEADBEEF
