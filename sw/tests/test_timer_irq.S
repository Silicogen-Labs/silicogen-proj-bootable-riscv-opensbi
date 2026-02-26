// test_timer_irq.S
// Test timer interrupt functionality
// Expected output: 'P' (pass)

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
    
    // Enable timer interrupts (mie.MTIE = 1, bit 7)
    li t0, 0x80
    csrw mie, t0
    
    // Set mtimecmp to small value (will trigger soon)
    // mtimecmp is at 0x02004000
    li t0, 0x02004000
    li t1, 100          // Interrupt after 100 cycles
    sw t1, 0(t0)        // Write mtimecmp low word
    sw zero, 4(t0)      // Write mtimecmp high word = 0
    
    // Wait for interrupt - we should never get past this loop
    // because the timer interrupt will fire
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
    // Read mcause
    csrr t0, mcause
    
    // Check if interrupt bit (bit 31) is set
    srli t1, t0, 31
    beqz t1, not_interrupt
    
    // It's an interrupt - print 'I'
    li a0, 'I'
    PRINT_CHAR a0
    j check_code
    
not_interrupt:
    // It's an exception - print 'E'
    li a0, 'E'
    PRINT_CHAR a0
    j check_code
    
check_code:
    // Check if code is 7
    andi t1, t0, 0xFF
    li t2, 7
    bne t1, t2, wrong_code
    
    // Code is correct - print '7'
    li a0, '7'
    PRINT_CHAR a0
    j success
    
wrong_code:
    // Wrong code - print the code + '0' to see what it is
    addi a0, t1, '0'
    PRINT_CHAR a0
    j fail
    
success:
    // Clear interrupt by setting mtimecmp to max value
    // Use s0/s1 instead of t0/t1 to avoid conflicts
    lui s0, 0x2004      // s0 = 0x02004000
    li s1, -1           // s1 = 0xFFFFFFFF
    sw s1, 0(s0)        // mtimecmp low = 0xFFFFFFFF
    sw s1, 4(s0)        // mtimecmp high = 0xFFFFFFFF
    
    // Now print 'P' for pass
    li a0, 'P'
    PRINT_CHAR a0
    
    TEST_HALT
    
fail:
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT
