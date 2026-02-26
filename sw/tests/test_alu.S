# RISC-V ALU Test Suite
#
# Tests all RV32I arithmetic, logical, shift, and comparison instructions
# Uses test framework for self-checking results

.include "test_framework.h"

.section .text
.globl _start

_start:
    # Initialize test framework
    TEST_INIT
    
    # Set up stack pointer
    lui sp, %hi(0x00400000)      # Stack at end of 4MB RAM
    addi sp, sp, %lo(0x00400000)
    
    # Run all test groups
    call test_arithmetic
    call test_logical
    call test_shifts
    call test_comparisons
    call test_upper_immediate
    
    # Mark test complete and halt
    TEST_DONE
    TEST_HALT

# =============================================================================
# Arithmetic Instructions: ADD, ADDI, SUB
# =============================================================================
test_arithmetic:
    # Test ID 0: ADD positive numbers
    li a0, 100
    li a1, 200
    add a2, a0, a1
    li a3, 300
    CHECK_EQUAL a2, a3, 0
    
    # Test ID 1: ADD negative numbers
    li a0, -50
    li a1, -25
    add a2, a0, a1
    li a3, -75
    CHECK_EQUAL a2, a3, 1
    
    # Test ID 2: ADD overflow (wraps around)
    li a0, 0x7FFFFFFF            # Max positive int
    li a1, 1
    add a2, a0, a1
    li a3, 0x80000000            # Min negative int
    CHECK_EQUAL a2, a3, 2
    
    # Test ID 3: ADDI positive immediate
    li a0, 100
    addi a1, a0, 50
    li a2, 150
    CHECK_EQUAL a1, a2, 3
    
    # Test ID 4: ADDI negative immediate
    li a0, 100
    addi a1, a0, -30
    li a2, 70
    CHECK_EQUAL a1, a2, 4
    
    # Test ID 5: ADDI with zero
    li a0, 42
    addi a1, a0, 0
    CHECK_EQUAL a1, a0, 5
    
    # Test ID 6: SUB basic
    li a0, 100
    li a1, 30
    sub a2, a0, a1
    li a3, 70
    CHECK_EQUAL a2, a3, 6
    
    # Test ID 7: SUB resulting in negative
    li a0, 50
    li a1, 100
    sub a2, a0, a1
    li a3, -50
    CHECK_EQUAL a2, a3, 7
    
    # Test ID 8: SUB same registers (should be zero)
    li a0, 123
    sub a1, a0, a0
    CHECK_ZERO a1, 8
    
    ret

# =============================================================================
# Logical Instructions: AND, ANDI, OR, ORI, XOR, XORI
# =============================================================================
test_logical:
    # Test ID 10: AND
    li a0, 0xFF00FF00
    li a1, 0x0FF00FF0
    and a2, a0, a1
    li a3, 0x0F000F00
    CHECK_EQUAL a2, a3, 10
    
    # Test ID 11: ANDI
    li a0, 0xFFFFFFFF
    andi a1, a0, 0x7FF           # 11-bit immediate
    li a2, 0x000007FF
    CHECK_EQUAL a1, a2, 11
    
    # Test ID 12: OR
    li a0, 0xF0F0F0F0
    li a1, 0x0F0F0F0F
    or a2, a0, a1
    li a3, 0xFFFFFFFF
    CHECK_EQUAL a2, a3, 12
    
    # Test ID 13: ORI
    li a0, 0xFFFF0000
    ori a1, a0, 0x7FF
    li a2, 0xFFFF07FF
    CHECK_EQUAL a1, a2, 13
    
    # Test ID 14: XOR (exclusive or)
    li a0, 0xF0F0F0F0
    li a1, 0xFFFFFFFF
    xor a2, a0, a1
    li a3, 0x0F0F0F0F
    CHECK_EQUAL a2, a3, 14
    
    # Test ID 15: XOR same register (should be zero)
    li a0, 0xDEADBEEF
    xor a1, a0, a0
    CHECK_ZERO a1, 15
    
    # Test ID 16: XORI
    li a0, 0xFFFFFFFF
    xori a1, a0, 0x555           # Toggle some bits
    li a2, 0xFFFFFAAA
    CHECK_EQUAL a1, a2, 16
    
    ret

# =============================================================================
# Shift Instructions: SLL, SLLI, SRL, SRLI, SRA, SRAI
# =============================================================================
test_shifts:
    # Test ID 20: SLL (Shift Left Logical)
    li a0, 0x00000001
    li a1, 8
    sll a2, a0, a1
    li a3, 0x00000100
    CHECK_EQUAL a2, a3, 20
    
    # Test ID 21: SLLI (Shift Left Logical Immediate)
    li a0, 0x00000003
    slli a1, a0, 4
    li a2, 0x00000030
    CHECK_EQUAL a1, a2, 21
    
    # Test ID 22: SLL by 0 (no change)
    li a0, 0xABCDEF01
    li a1, 0
    sll a2, a0, a1
    CHECK_EQUAL a2, a0, 22
    
    # Test ID 23: SRL (Shift Right Logical - zero fill)
    li a0, 0x80000000
    li a1, 4
    srl a2, a0, a1
    li a3, 0x08000000
    CHECK_EQUAL a2, a3, 23
    
    # Test ID 24: SRLI
    li a0, 0xFF000000
    srli a1, a0, 8
    li a2, 0x00FF0000
    CHECK_EQUAL a1, a2, 24
    
    # Test ID 25: SRA (Shift Right Arithmetic - sign extend)
    li a0, 0x80000000            # Negative number
    li a1, 4
    sra a2, a0, a1
    li a3, 0xF8000000            # Sign extended
    CHECK_EQUAL a2, a3, 25
    
    # Test ID 26: SRAI with positive number
    li a0, 0x7FFFFFFF
    srai a1, a0, 4
    li a2, 0x07FFFFFF
    CHECK_EQUAL a1, a2, 26
    
    # Test ID 27: SRAI with negative number
    li a0, 0xFFFFFF00
    srai a1, a0, 4
    li a2, 0xFFFFFFFF
    CHECK_EQUAL a1, a2, 27
    
    # Test ID 28: Shift by maximum (31 bits)
    li a0, 0xFFFFFFFF
    li a1, 31
    srl a2, a0, a1
    li a3, 0x00000001
    CHECK_EQUAL a2, a3, 28
    
    ret

# =============================================================================
# Comparison Instructions: SLT, SLTI, SLTU, SLTIU
# =============================================================================
test_comparisons:
    # Test ID 30: SLT (Set Less Than - signed)
    li a0, -10
    li a1, 10
    slt a2, a0, a1               # -10 < 10 (true, should be 1)
    li a3, 1
    CHECK_EQUAL a2, a3, 30
    
    # Test ID 31: SLT false case
    li a0, 100
    li a1, 50
    slt a2, a0, a1               # 100 < 50 (false, should be 0)
    CHECK_ZERO a2, 31
    
    # Test ID 32: SLT equal (should be 0)
    li a0, 42
    li a1, 42
    slt a2, a0, a1               # 42 < 42 (false, should be 0)
    CHECK_ZERO a2, 32
    
    # Test ID 33: SLTI
    li a0, 50
    slti a1, a0, 100             # 50 < 100 (true)
    li a2, 1
    CHECK_EQUAL a1, a2, 33
    
    # Test ID 34: SLTI with negative
    li a0, -5
    slti a1, a0, 10              # -5 < 10 (true)
    li a2, 1
    CHECK_EQUAL a1, a2, 34
    
    # Test ID 35: SLTU (unsigned comparison)
    li a0, 0xFFFFFFFF            # -1 as signed, max as unsigned
    li a1, 1
    sltu a2, a0, a1              # 0xFFFFFFFF < 1 unsigned (false)
    CHECK_ZERO a2, 35
    
    # Test ID 36: SLTU opposite
    li a0, 1
    li a1, 0xFFFFFFFF
    sltu a2, a0, a1              # 1 < 0xFFFFFFFF unsigned (true)
    li a3, 1
    CHECK_EQUAL a2, a3, 36
    
    # Test ID 37: SLTIU
    li a0, 100
    sltiu a1, a0, 200            # 100 < 200 unsigned (true)
    li a2, 1
    CHECK_EQUAL a1, a2, 37
    
    # Test ID 38: SLTIU with large value
    li a0, 0xFFFFFFFF
    sltiu a1, a0, 10             # Max unsigned < 10 (false)
    CHECK_ZERO a1, 38
    
    ret

# =============================================================================
# Upper Immediate Instructions: LUI, AUIPC
# =============================================================================
test_upper_immediate:
    # Test ID 40: LUI (Load Upper Immediate)
    lui a0, 0x12345
    li a1, 0x12345000
    CHECK_EQUAL a0, a1, 40
    
    # Test ID 41: LUI with zeros
    lui a0, 0
    CHECK_ZERO a0, 41
    
    # Test ID 42: AUIPC (Add Upper Immediate to PC)
    auipc a0, 0                  # a0 = current PC + 0
    # We can't check exact PC, but verify it's non-zero and reasonable
    CHECK_NONZERO a0, 42
    
    # Test ID 43: AUIPC with offset
    auipc a0, 1                  # a0 = PC + 0x1000
    auipc a1, 2                  # a1 = PC + 0x2000
    # a1 should be > a0 (roughly a0 + 0x1000)
    sub a2, a1, a0
    li a3, 0x0FFF                # Should be around 0x1000
    CHECK_GT a2, a3, 43
    
    ret

# =============================================================================
# Data Section
# =============================================================================
.section .data
.align 4

test_data:
    .word 0xDEADBEEF
    .word 0xCAFEBABE
    .word 0x12345678
    .word 0xABCDEF01
