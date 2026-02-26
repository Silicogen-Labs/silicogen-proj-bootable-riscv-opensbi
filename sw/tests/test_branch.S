# RISC-V Branch and Jump Test Suite
#
# Tests all branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
# and jump instructions (JAL, JALR)
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
    call test_beq
    call test_bne
    call test_blt
    call test_bge
    call test_bltu
    call test_bgeu
    call test_jal
    call test_jalr
    
    # Mark test complete and halt
    TEST_DONE
    TEST_HALT

# =============================================================================
# BEQ (Branch if Equal)
# =============================================================================
test_beq:
    # Test ID 0: BEQ taken (equal values)
    li a0, 42
    li a1, 42
    li a2, 0                      # Default: fail
    beq a0, a1, 1f                # Should branch
    j 2f                          # Should not execute
1:  li a2, 1                      # Mark success
2:  li a3, 1
    CHECK_EQUAL a2, a3, 0
    
    # Test ID 1: BEQ not taken (different values)
    li a0, 10
    li a1, 20
    li a2, 1                      # Default: success
    beq a0, a1, 1f                # Should NOT branch
    j 2f
1:  li a2, 0                      # Should not reach here
2:  li a3, 1
    CHECK_EQUAL a2, a3, 1
    
    # Test ID 2: BEQ with zero register
    li a0, 0
    li a2, 0
    beq a0, x0, 1f                # Should branch
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 2
    
    # Test ID 3: BEQ backward branch
    li a0, 100
    li a1, 100
    j 1f
3:  li a2, 1                      # Target of backward branch
    j 2f
1:  li a2, 0
    beq a0, a1, 3b                # Branch backward
2:  li a3, 1
    CHECK_EQUAL a2, a3, 3
    
    ret

# =============================================================================
# BNE (Branch if Not Equal)
# =============================================================================
test_bne:
    # Test ID 5: BNE taken (different values)
    li a0, 10
    li a1, 20
    li a2, 0
    bne a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 5
    
    # Test ID 6: BNE not taken (equal values)
    li a0, 42
    li a1, 42
    li a2, 1
    bne a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 6
    
    # Test ID 7: BNE with negative numbers
    li a0, -10
    li a1, -20
    li a2, 0
    bne a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 7
    
    ret

# =============================================================================
# BLT (Branch if Less Than - signed)
# =============================================================================
test_blt:
    # Test ID 10: BLT taken (a < b)
    li a0, 10
    li a1, 20
    li a2, 0
    blt a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 10
    
    # Test ID 11: BLT not taken (a >= b)
    li a0, 30
    li a1, 20
    li a2, 1
    blt a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 11
    
    # Test ID 12: BLT with negative (negative < positive)
    li a0, -10
    li a1, 10
    li a2, 0
    blt a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 12
    
    # Test ID 13: BLT with both negative
    li a0, -20
    li a1, -10
    li a2, 0
    blt a0, a1, 1f                # -20 < -10 (true)
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 13
    
    # Test ID 14: BLT equal (should not branch)
    li a0, 42
    li a1, 42
    li a2, 1
    blt a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 14
    
    ret

# =============================================================================
# BGE (Branch if Greater or Equal - signed)
# =============================================================================
test_bge:
    # Test ID 15: BGE taken (a >= b)
    li a0, 30
    li a1, 20
    li a2, 0
    bge a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 15
    
    # Test ID 16: BGE not taken (a < b)
    li a0, 10
    li a1, 20
    li a2, 1
    bge a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 16
    
    # Test ID 17: BGE equal (should branch)
    li a0, 42
    li a1, 42
    li a2, 0
    bge a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 17
    
    # Test ID 18: BGE with negative
    li a0, 10
    li a1, -10
    li a2, 0
    bge a0, a1, 1f                # 10 >= -10 (true)
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 18
    
    ret

# =============================================================================
# BLTU (Branch if Less Than - unsigned)
# =============================================================================
test_bltu:
    # Test ID 20: BLTU taken
    li a0, 10
    li a1, 20
    li a2, 0
    bltu a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 20
    
    # Test ID 21: BLTU not taken
    li a0, 30
    li a1, 20
    li a2, 1
    bltu a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 21
    
    # Test ID 22: BLTU with "negative" as unsigned
    li a0, -1                     # 0xFFFFFFFF as unsigned
    li a1, 1
    li a2, 1
    bltu a0, a1, 1f               # 0xFFFFFFFF < 1 unsigned (false)
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 22
    
    # Test ID 23: BLTU opposite
    li a0, 1
    li a1, -1                     # 0xFFFFFFFF
    li a2, 0
    bltu a0, a1, 1f               # 1 < 0xFFFFFFFF unsigned (true)
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 23
    
    ret

# =============================================================================
# BGEU (Branch if Greater or Equal - unsigned)
# =============================================================================
test_bgeu:
    # Test ID 25: BGEU taken
    li a0, 30
    li a1, 20
    li a2, 0
    bgeu a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 25
    
    # Test ID 26: BGEU not taken
    li a0, 10
    li a1, 20
    li a2, 1
    bgeu a0, a1, 1f
    j 2f
1:  li a2, 0
2:  li a3, 1
    CHECK_EQUAL a2, a3, 26
    
    # Test ID 27: BGEU with unsigned large value
    li a0, -1                     # 0xFFFFFFFF
    li a1, 1
    li a2, 0
    bgeu a0, a1, 1f               # 0xFFFFFFFF >= 1 (true)
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 27
    
    # Test ID 28: BGEU equal
    li a0, 42
    li a1, 42
    li a2, 0
    bgeu a0, a1, 1f
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 28
    
    ret

# =============================================================================
# JAL (Jump and Link)
# =============================================================================
test_jal:
    # Test ID 30: JAL basic
    li a2, 0
    jal a0, 1f                    # Jump, save return address in a0
    j 2f                          # Should not execute
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 30
    
    # Test ID 31: JAL return address check
    # Return address should be PC+4 (next instruction)
    jal a0, 1f
    j 2f
1:  # a0 should contain address of the "j 2f" instruction
    # We can't check exact address, but verify it's non-zero
    CHECK_NONZERO a0, 31
2:
    
    # Test ID 32: JAL to x0 (no link)
    li a2, 0
    jal x0, 1f                    # Jump without saving return
    j 2f
1:  li a2, 1
2:  li a3, 1
    CHECK_EQUAL a2, a3, 32
    
    # Test ID 33: JAL forward jump
    li a2, 0
    jal ra, jal_target
    li a2, 0                      # Should not execute
    j jal_end
jal_target:
    li a2, 1
jal_end:
    li a3, 1
    CHECK_EQUAL a2, a3, 33
    
    ret

# =============================================================================
# JALR (Jump and Link Register)
# =============================================================================
test_jalr:
    # Test ID 35: JALR basic
    la a0, jalr_target1
    li a2, 0
    jalr a1, a0, 0                # Jump to address in a0
    j jalr_skip1
jalr_target1:
    li a2, 1
jalr_skip1:
    li a3, 1
    CHECK_EQUAL a2, a3, 35
    
    # Test ID 36: JALR with offset
    la a0, jalr_target2
    addi a0, a0, -4               # Start 4 bytes before
    li a2, 0
    jalr a1, a0, 4                # Add offset of 4
    j jalr_skip2
jalr_target2:
    li a2, 1
jalr_skip2:
    li a3, 1
    CHECK_EQUAL a2, a3, 36
    
    # Test ID 37: JALR return address
    la a0, jalr_target3
    jalr a1, a0, 0
    # a1 should contain return address
    CHECK_NONZERO a1, 37
    j jalr_skip3
jalr_target3:
    j jalr_skip3
jalr_skip3:
    
    # Test ID 38: JALR LSB clearing
    # JALR should clear LSB of computed address
    la a0, jalr_target4
    ori a0, a0, 1                 # Set LSB (invalid)
    li a2, 0
    jalr x0, a0, 0                # Should clear LSB and jump correctly
    j jalr_skip4
jalr_target4:
    li a2, 1
jalr_skip4:
    li a3, 1
    CHECK_EQUAL a2, a3, 38
    
    # Test ID 39: JALR indirect function call
    la a0, simple_func
    jalr ra, a0, 0                # Call function
    # a2 should be set by function
    li a3, 0xABCD
    CHECK_EQUAL a2, a3, 39
    
    ret

# Simple function for JALR test
simple_func:
    li a2, 0xABCD
    jr ra                         # Return (jalr x0, ra, 0)

# =============================================================================
# Data Section
# =============================================================================
.section .data
.align 4

test_data:
    .word 0xDEADBEEF
