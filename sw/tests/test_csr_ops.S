// test_csr_ops.S
// Test CSR instruction variants: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
// Expected output: 'P' (pass)

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Test CSRRW (CSR Read/Write)
    li t0, 0x12345678
    csrw mscratch, t0       // Write to mscratch
    csrr t1, mscratch       // Read back
    bne t0, t1, fail        // Should match
    
    // Test CSRRS (CSR Read and Set bits)
    li t0, 0x0F0F0F0F
    csrw mscratch, t0       // Write initial value
    li t1, 0xF0F0F0F0
    csrrs t2, mscratch, t1  // Set bits, return old value
    bne t2, t0, fail        // Should return old value
    csrr t3, mscratch       // Read new value
    li t4, 0xFFFFFFFF       // Should be OR of both
    bne t3, t4, fail
    
    // Test CSRRC (CSR Read and Clear bits)
    li t0, 0xFFFFFFFF
    csrw mscratch, t0       // Write all 1s
    li t1, 0x0F0F0F0F
    csrrc t2, mscratch, t1  // Clear bits, return old value
    bne t2, t0, fail        // Should return old value
    csrr t3, mscratch       // Read new value
    li t4, 0xF0F0F0F0       // Should have cleared bits
    bne t3, t4, fail
    
    // Test CSRRWI (CSR Read/Write Immediate)
    li t0, 0x1F             // 5-bit immediate max
    csrrwi t1, mscratch, 0x1F
    csrr t2, mscratch
    bne t2, t0, fail        // Should have written immediate
    
    // Test CSRRSI (CSR Read/Set Immediate)
    li t0, 0x0F
    csrw mscratch, t0
    csrrsi t1, mscratch, 0x10  // Set bit 4
    li t2, 0x1F
    csrr t3, mscratch
    bne t3, t2, fail        // Should be 0x1F
    
    // Test CSRRCI (CSR Read/Clear Immediate)
    li t0, 0x1F
    csrw mscratch, t0
    csrrci t1, mscratch, 0x0F  // Clear lower 4 bits
    li t2, 0x10
    csrr t3, mscratch
    bne t3, t2, fail        // Should be 0x10
    
    // Test reading read-only CSRs
    csrr t0, misa           // Should not trap
    csrr t1, mhartid        // Should not trap
    
    // All tests passed
    li a0, 'P'
    PRINT_CHAR a0
    TEST_HALT

fail:
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT
