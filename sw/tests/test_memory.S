# RISC-V Memory Access Test Suite
#
# Tests all load and store instructions with various alignments and byte/halfword accesses
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
    call test_word_access
    call test_halfword_access
    call test_byte_access
    call test_sign_extension
    call test_unaligned_access
    
    # Mark test complete and halt
    TEST_DONE
    TEST_HALT

# =============================================================================
# Word Load/Store: LW, SW
# =============================================================================
test_word_access:
    # Test ID 0: Basic SW/LW
    la a0, test_buffer
    li a1, 0xDEADBEEF
    sw a1, 0(a0)
    lw a2, 0(a0)
    CHECK_EQUAL a2, a1, 0
    
    # Test ID 1: SW/LW with offset
    li a1, 0xCAFEBABE
    sw a1, 4(a0)
    lw a2, 4(a0)
    CHECK_EQUAL a2, a1, 1
    
    # Test ID 2: SW/LW with large offset
    li a1, 0x12345678
    sw a1, 100(a0)
    lw a2, 100(a0)
    CHECK_EQUAL a2, a1, 2
    
    # Test ID 3: SW/LW with negative offset (use register arithmetic)
    addi a3, a0, 200
    li a1, 0xABCDEF01
    sw a1, 0(a3)
    lw a2, -200(a3)
    CHECK_EQUAL a2, a1, 3
    
    # Test ID 4: Multiple sequential stores/loads
    li a1, 0x11111111
    li a2, 0x22222222
    li a3, 0x33333333
    li a4, 0x44444444
    sw a1, 0(a0)
    sw a2, 4(a0)
    sw a3, 8(a0)
    sw a4, 12(a0)
    lw a5, 0(a0)
    lw a6, 4(a0)
    CHECK_EQUAL a5, a1, 4
    
    ret

# =============================================================================
# Halfword Load/Store: LH, LHU, SH
# =============================================================================
test_halfword_access:
    la a0, test_buffer
    
    # Test ID 10: SH/LH basic (signed)
    li a1, 0x00007FFF            # Positive halfword
    sh a1, 0(a0)
    lh a2, 0(a0)
    li a3, 0x00007FFF
    CHECK_EQUAL a2, a3, 10
    
    # Test ID 11: SH/LH negative (sign extension)
    li a1, 0x00008000            # -32768 as halfword
    sh a1, 2(a0)
    lh a2, 2(a0)
    li a3, 0xFFFF8000            # Sign extended
    CHECK_EQUAL a2, a3, 11
    
    # Test ID 12: LHU (unsigned, zero extension)
    li a1, 0x00008000
    sh a1, 4(a0)
    lhu a2, 4(a0)
    li a3, 0x00008000            # Zero extended
    CHECK_EQUAL a2, a3, 12
    
    # Test ID 13: LHU with large value
    li a1, 0x0000FFFF
    sh a1, 6(a0)
    lhu a2, 6(a0)
    li a3, 0x0000FFFF
    CHECK_EQUAL a2, a3, 13
    
    # Test ID 14: SH only affects 16 bits
    li a1, 0xFFFFFFFF
    sw a1, 8(a0)                 # Write full word
    li a2, 0x00001234
    sh a2, 8(a0)                 # Overwrite lower halfword
    lw a3, 8(a0)
    li a4, 0xFFFF1234            # Upper half preserved
    CHECK_EQUAL a3, a4, 14
    
    # Test ID 15: Multiple halfwords in one word
    li a1, 0xAAAA
    li a2, 0xBBBB
    sh a1, 12(a0)                # Lower half
    sh a2, 14(a0)                # Upper half
    lw a3, 12(a0)
    li a4, 0xBBBBAAAA
    CHECK_EQUAL a3, a4, 15
    
    ret

# =============================================================================
# Byte Load/Store: LB, LBU, SB
# =============================================================================
test_byte_access:
    la a0, test_buffer
    
    # Test ID 20: SB/LB basic
    li a1, 0x0000007F             # Positive byte
    sb a1, 0(a0)
    lb a2, 0(a0)
    li a3, 0x0000007F
    CHECK_EQUAL a2, a3, 20
    
    # Test ID 21: SB/LB negative (sign extension)
    li a1, 0x00000080             # -128 as byte
    sb a1, 1(a0)
    lb a2, 1(a0)
    li a3, 0xFFFFFF80             # Sign extended
    CHECK_EQUAL a2, a3, 21
    
    # Test ID 22: LBU (unsigned, zero extension)
    li a1, 0x000000FF
    sb a1, 2(a0)
    lbu a2, 2(a0)
    li a3, 0x000000FF
    CHECK_EQUAL a2, a3, 22
    
    # Test ID 23: LBU with 0x80
    li a1, 0x00000080
    sb a1, 3(a0)
    lbu a2, 3(a0)
    li a3, 0x00000080             # Not sign extended
    CHECK_EQUAL a2, a3, 23
    
    # Test ID 24: SB only affects 8 bits
    li a1, 0xFFFFFFFF
    sw a1, 4(a0)
    li a2, 0x00000042
    sb a2, 4(a0)                  # Overwrite byte 0
    lw a3, 4(a0)
    li a4, 0xFFFFFF42
    CHECK_EQUAL a3, a4, 24
    
    # Test ID 25: Four bytes in one word
    li a1, 0x11
    li a2, 0x22
    li a3, 0x33
    li a4, 0x44
    sb a1, 8(a0)
    sb a2, 9(a0)
    sb a3, 10(a0)
    sb a4, 11(a0)
    lw a5, 8(a0)
    li a6, 0x44332211
    CHECK_EQUAL a5, a6, 25
    
    # Test ID 26: Read individual bytes back
    lbu a1, 8(a0)
    li a2, 0x11
    CHECK_EQUAL a1, a2, 26
    
    # Test ID 27: Read byte 1
    lbu a1, 9(a0)
    li a2, 0x22
    CHECK_EQUAL a1, a2, 27
    
    # Test ID 28: Read byte 2
    lbu a1, 10(a0)
    li a2, 0x33
    CHECK_EQUAL a1, a2, 28
    
    # Test ID 29: Read byte 3
    lbu a1, 11(a0)
    li a2, 0x44
    CHECK_EQUAL a1, a2, 29
    
    ret

# =============================================================================
# Sign Extension Tests
# =============================================================================
test_sign_extension:
    la a0, test_buffer
    
    # Test ID 30: LB sign extension (positive)
    li a1, 0x0000007F
    sb a1, 0(a0)
    lb a2, 0(a0)
    li a3, 0x0000007F             # Should not sign extend (MSB=0)
    CHECK_EQUAL a2, a3, 30
    
    # Test ID 31: LB sign extension (negative)
    li a1, 0x000000FF
    sb a1, 1(a0)
    lb a2, 1(a0)
    li a3, 0xFFFFFFFF             # Should sign extend (MSB=1)
    CHECK_EQUAL a2, a3, 31
    
    # Test ID 32: LH sign extension (positive)
    li a1, 0x00007FFF
    sh a1, 2(a0)
    lh a2, 2(a0)
    li a3, 0x00007FFF
    CHECK_EQUAL a2, a3, 32
    
    # Test ID 33: LH sign extension (negative)
    li a1, 0x0000FFFF
    sh a1, 4(a0)
    lh a2, 4(a0)
    li a3, 0xFFFFFFFF
    CHECK_EQUAL a2, a3, 33
    
    # Test ID 34: LBU never sign extends
    li a1, 0x000000FF
    sb a1, 6(a0)
    lbu a2, 6(a0)
    li a3, 0x000000FF             # Zero extended
    CHECK_EQUAL a2, a3, 34
    
    # Test ID 35: LHU never sign extends
    li a1, 0x0000FFFF
    sh a1, 8(a0)
    lhu a2, 8(a0)
    li a3, 0x0000FFFF             # Zero extended
    CHECK_EQUAL a2, a3, 35
    
    ret

# =============================================================================
# Unaligned Access Tests (within word boundaries)
# =============================================================================
test_unaligned_access:
    la a0, test_buffer
    
    # Test ID 40: Byte access at all offsets
    li a1, 0xAA
    li a2, 0xBB
    li a3, 0xCC
    li a4, 0xDD
    sb a1, 0(a0)
    sb a2, 1(a0)
    sb a3, 2(a0)
    sb a4, 3(a0)
    lbu a5, 0(a0)
    CHECK_EQUAL a5, a1, 40
    
    # Test ID 41: Halfword at offset 0
    li a1, 0x1234
    sh a1, 4(a0)
    lhu a2, 4(a0)
    CHECK_EQUAL a2, a1, 41
    
    # Test ID 42: Halfword at offset 2 (aligned)
    li a1, 0x5678
    sh a1, 6(a0)
    lhu a2, 6(a0)
    CHECK_EQUAL a2, a1, 42
    
    # Test ID 43: Overlapping access pattern
    # Write word, read as bytes
    li a1, 0x12345678
    sw a1, 8(a0)
    lbu a2, 8(a0)
    li a3, 0x78
    CHECK_EQUAL a2, a3, 43
    
    # Test ID 44: Read byte 1 of word
    lbu a2, 9(a0)
    li a3, 0x56
    CHECK_EQUAL a2, a3, 44
    
    # Test ID 45: Read as halfword
    lhu a2, 8(a0)
    li a3, 0x5678
    CHECK_EQUAL a2, a3, 45
    
    ret

# =============================================================================
# Data Section
# =============================================================================
.section .bss
.align 4

# Test buffer (256 bytes)
test_buffer:
    .space 256
