// test_sw_irq.S
// Test software interrupt functionality
// Expected output: 'I3P' (Interrupt, code 3, Pass)

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Set up trap handler
1:  auipc t0, %pcrel_hi(trap_handler)
    addi t0, t0, %pcrel_lo(1b)
    csrw mtvec, t0
    
    // Enable global interrupts (mstatus.MIE = 1)
    li t0, 0x8
    csrs mstatus, t0
    
    // Enable software interrupts (mie.MSIE = 1, bit 3)
    li t0, 0x8
    csrw mie, t0
    
    // Trigger software interrupt by setting mip.MSIP (bit 3)
    li t0, 0x8
    csrw mip, t0
    
    // Wait - interrupt should occur immediately
wait_loop:
    nop
    nop
    nop
    nop
    j wait_loop
    
    // Should never reach here
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT

trap_handler:
    // Print 'I' for interrupt
    li a0, 'I'
    PRINT_CHAR a0
    
    // Read mcause
    csrr t0, mcause
    
    // Check if code is 3 (software interrupt)
    andi t1, t0, 0xFF
    li t2, 3
    bne t1, t2, wrong_code
    
    // Print '3' for code 3
    li a0, '3'
    PRINT_CHAR a0
    
    // Clear software interrupt by clearing mip.MSIP
    li t0, 0x8
    csrc mip, t0
    
    // Print 'P' for pass
    li a0, 'P'
    PRINT_CHAR a0
    
    TEST_HALT
    
wrong_code:
    // Wrong code - print the code + '0'
    addi a0, t1, '0'
    PRINT_CHAR a0
    
fail:
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT
