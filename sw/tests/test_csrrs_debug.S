// test_csrrs_debug.S
// Debug CSRRS operation
// Print what value CSRRS returns

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Set mscratch to 0x0F
    li t0, 0x0F
    csrw mscratch, t0
    
    // Do CSRRS with 0xF0
    li t1, 0xF0
    csrrs t2, mscratch, t1
    
    // Print the lower 4 bits of t2
    andi t3, t2, 0x0F
    addi a0, t3, '0'
    PRINT_CHAR a0
    
    // Read mscratch to see new value
    csrr t4, mscratch
    andi t5, t4, 0xFF
    
    // Print lower nibble
    andi t6, t5, 0x0F
    addi a0, t6, '0'
    PRINT_CHAR a0
    
    // Print upper nibble
    srli t6, t5, 4
    andi t6, t6, 0x0F
    addi a0, t6, '0'
    PRINT_CHAR a0
    
    li a0, 'P'
    PRINT_CHAR a0
    TEST_HALT
