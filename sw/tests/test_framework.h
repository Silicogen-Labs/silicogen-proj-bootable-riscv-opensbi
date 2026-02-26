# RISC-V Test Framework
# 
# Provides macros for writing self-checking assembly tests
# Results are stored in memory for testbench to verify

# =============================================================================
# Memory Regions
# =============================================================================

# Test results stored at 0x3F00 (near end of 4MB RAM)
.equ TEST_RESULT_BASE, 0x3F00
.equ TEST_STATUS_ADDR, 0x3FFC    # Overall test status (last word)

# Test result values
.equ TEST_PASS, 0x1
.equ TEST_FAIL, 0x0
.equ TEST_MAGIC_DONE, 0xDEADBEEF  # Magic value to signal completion

# UART base address for optional debug output
.equ UART_BASE, 0x10000000
.equ UART_THR, 0x00              # Transmit Holding Register
.equ UART_LSR, 0x05              # Line Status Register

# =============================================================================
# Test Control Macros
# =============================================================================

# Initialize test framework
# Sets all result slots to 0, sets status to "running"
.macro TEST_INIT
    li t0, TEST_RESULT_BASE
    li t1, 0
    li t2, 256                    # Clear 256 words (1KB)
1:
    sw t1, 0(t0)
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, 1b
.endm

# Mark overall test as complete
# Writes magic value to status address
.macro TEST_DONE
    li t0, TEST_STATUS_ADDR
    li t1, TEST_MAGIC_DONE
    sw t1, 0(t0)
.endm

# Halt simulation (infinite loop)
.macro TEST_HALT
    j .
.endm

# =============================================================================
# Assertion Macros
# =============================================================================

# Check if two registers are equal
# Args: reg_actual, reg_expected, test_id (0-255)
# Result stored at TEST_RESULT_BASE + (test_id * 4)
.macro CHECK_EQUAL reg_actual, reg_expected, test_id
    li t6, TEST_RESULT_BASE
    beq \reg_actual, \reg_expected, 1f
    # Test failed
    li t5, TEST_FAIL
    sw t5, (\test_id * 4)(t6)
    j 2f
1:  
    # Test passed
    li t5, TEST_PASS
    sw t5, (\test_id * 4)(t6)
2:
.endm

# Check if register is zero
# Args: reg, test_id
.macro CHECK_ZERO reg, test_id
    li t6, TEST_RESULT_BASE
    beqz \reg, 1f
    # Failed (not zero)
    li t5, TEST_FAIL
    sw t5, (\test_id * 4)(t6)
    j 2f
1:
    # Passed (is zero)
    li t5, TEST_PASS
    sw t5, (\test_id * 4)(t6)
2:
.endm

# Check if register is non-zero
# Args: reg, test_id
.macro CHECK_NONZERO reg, test_id
    li t6, TEST_RESULT_BASE
    bnez \reg, 1f
    # Failed (is zero)
    li t5, TEST_FAIL
    sw t5, (\test_id * 4)(t6)
    j 2f
1:
    # Passed (non-zero)
    li t5, TEST_PASS
    sw t5, (\test_id * 4)(t6)
2:
.endm

# Check if register is greater than another register
# Args: reg1, reg2, test_id (pass if reg1 > reg2)
.macro CHECK_GT reg1, reg2, test_id
    li t6, TEST_RESULT_BASE
    bgt \reg1, \reg2, 1f
    # Failed (not greater)
    li t5, TEST_FAIL
    sw t5, (\test_id * 4)(t6)
    j 2f
1:
    # Passed (is greater)
    li t5, TEST_PASS
    sw t5, (\test_id * 4)(t6)
2:
.endm

# Check if register is less than another register
# Args: reg1, reg2, test_id (pass if reg1 < reg2)
.macro CHECK_LT reg1, reg2, test_id
    li t6, TEST_RESULT_BASE
    blt \reg1, \reg2, 1f
    # Failed (not less)
    li t5, TEST_FAIL
    sw t5, (\test_id * 4)(t6)
    j 2f
1:
    # Passed (is less)
    li t5, TEST_PASS
    sw t5, (\test_id * 4)(t6)
2:
.endm

# =============================================================================
# Debug Output Macros (Optional - uses UART)
# =============================================================================

# Print a single character to UART
# Args: char_reg (register containing character)
# Clobbers: t3, t4
.macro PRINT_CHAR char_reg
    li t3, UART_BASE
1:  
    # Wait for TX ready (LSR bit 5)
    lbu t4, UART_LSR(t3)
    andi t4, t4, 0x20
    beqz t4, 1b
    # Write character
    sb \char_reg, UART_THR(t3)
.endm

# Print newline
.macro PRINT_NEWLINE
    li t4, 10                     # '\n'
    PRINT_CHAR t4
.endm

# =============================================================================
# Helper Macros
# =============================================================================

# Load immediate 32-bit value (pseudo-instruction helper)
# Args: reg, immediate
.macro LI32 reg, imm
    lui \reg, %hi(\imm)
    addi \reg, \reg, %lo(\imm)
.endm

# No operation (delay)
.macro NOP
    addi x0, x0, 0
.endm

# =============================================================================
# Test Result Storage Format
# =============================================================================
#
# Memory Layout:
# 0x3F00 + (test_id * 4) = Test result (0 = FAIL, 1 = PASS)
# 0x3FFC = Overall status (0xDEADBEEF when complete)
#
# Example:
#   Test ID 0  -> 0x3F00
#   Test ID 1  -> 0x3F04
#   Test ID 2  -> 0x3F08
#   ...
#   Test ID 62 -> 0x3FF8
#   Status     -> 0x3FFC
#
# =============================================================================

# =============================================================================
# Example Usage
# =============================================================================
#
# .section .text
# .globl _start
# _start:
#     TEST_INIT                    # Initialize framework
#     
#     # Test 0: Simple addition
#     li t0, 5
#     li t1, 10
#     add t2, t0, t1
#     li t3, 15
#     CHECK_EQUAL t2, t3, 0        # Store result at 0x3F00
#     
#     # Test 1: Check zero
#     sub t4, t0, t0
#     CHECK_ZERO t4, 1             # Store result at 0x3F04
#     
#     TEST_DONE                    # Mark complete
#     TEST_HALT                    # Halt simulation
#
# =============================================================================
