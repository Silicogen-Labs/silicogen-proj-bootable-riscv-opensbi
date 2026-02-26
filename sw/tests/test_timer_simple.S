// test_timer_simple.S
// Simple test to write to timer registers
// Expected output: 'P' (pass)

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Try to write to mtimecmp
    li t0, 0x02004000
    li t1, 0x12345678
    sw t1, 0(t0)        // Write mtimecmp low
    
    // Read it back
    lw t2, 0(t0)
    
    // Check if it matches
    bne t1, t2, fail
    
    // Success
    li a0, 'P'
    PRINT_CHAR a0
    TEST_HALT
    
fail:
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT
