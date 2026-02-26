// test_csr_simple.S
// Simple test of CSR operations
// Expected output: '123456P'

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Test 1: CSRRW
    li t0, 0x12345678
    csrw mscratch, t0
    csrr t1, mscratch
    bne t0, t1, fail
    li a0, '1'
    PRINT_CHAR a0
    
    // Test 2: CSRRS
    li t0, 0x0F
    csrw mscratch, t0
    li t1, 0xF0
    csrrs t2, mscratch, t1
    li t3, 0x0F
    bne t2, t3, fail       // Old value should be 0x0F
    csrr t4, mscratch
    li t5, 0xFF
    bne t4, t5, fail       // New value should be 0xFF
    li a0, '2'
    PRINT_CHAR a0
    
    // Test 3: CSRRC
    li t0, 0xFF
    csrw mscratch, t0
    li t1, 0x0F
    csrrc t2, mscratch, t1
    li t3, 0xFF
    bne t2, t3, fail       // Old value should be 0xFF
    csrr t4, mscratch
    li t5, 0xF0
    bne t4, t5, fail       // New value should be 0xF0
    li a0, '3'
    PRINT_CHAR a0
    
    // Test 4: CSRRWI
    csrrwi t1, mscratch, 0x1F
    csrr t2, mscratch
    li t3, 0x1F
    bne t2, t3, fail
    li a0, '4'
    PRINT_CHAR a0
    
    // Test 5: CSRRSI
    li t0, 0x0F
    csrw mscratch, t0
    csrrsi t1, mscratch, 0x10
    csrr t2, mscratch
    li t3, 0x1F
    bne t2, t3, fail
    li a0, '5'
    PRINT_CHAR a0
    
    // Test 6: CSRRCI
    li t0, 0x1F
    csrw mscratch, t0
    csrrci t1, mscratch, 0x0F
    csrr t2, mscratch
    li t3, 0x10
    bne t2, t3, fail
    li a0, '6'
    PRINT_CHAR a0
    
    // All passed
    li a0, 'P'
    PRINT_CHAR a0
    TEST_HALT

fail:
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT
