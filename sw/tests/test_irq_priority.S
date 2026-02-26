// test_irq_priority.S
// Test interrupt priority: Software > Timer
// Expected output: 'S' then 'T' then 'P'

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Set up trap handler
1:  auipc t0, %pcrel_hi(trap_handler)
    addi t0, t0, %pcrel_lo(1b)
    csrw mtvec, t0
    
    // Set mtimecmp to small value first (timer will be pending)
    li t0, 0x02004000
    li t1, 50
    sw t1, 0(t0)        // mtimecmp low = 50
    sw zero, 4(t0)      // mtimecmp high = 0
    
    // Wait a bit for timer to become pending
    li t0, 100
delay:
    addi t0, t0, -1
    bnez t0, delay
    
    // Now set software interrupt (should have priority over timer)
    li t0, 0x8
    csrw mip, t0
    
    // Enable global interrupts
    li t0, 0x8
    csrs mstatus, t0
    
    // Enable both software and timer interrupts
    li t0, 0x88         // MSIE (bit 3) | MTIE (bit 7)
    csrw mie, t0
    
    // Wait for interrupts
wait_loop:
    nop
    nop
    j wait_loop
    
    // Should never reach here
    li a0, 'F'
    PRINT_CHAR a0
    TEST_HALT

trap_handler:
    // Read mcause to determine interrupt type
    csrr t0, mcause
    andi t1, t0, 0xFF
    
    // Check if software interrupt (code 3)
    li t2, 3
    beq t1, t2, handle_sw
    
    // Check if timer interrupt (code 7)
    li t2, 7
    beq t1, t2, handle_timer
    
    // Unknown interrupt
    li a0, 'U'
    PRINT_CHAR a0
    TEST_HALT

handle_sw:
    // Print 'S' for software interrupt
    li a0, 'S'
    PRINT_CHAR a0
    
    // Clear software interrupt
    li t0, 0x8
    csrc mip, t0
    
    // Return - should now take timer interrupt
    mret

handle_timer:
    // Print 'T' for timer interrupt
    li a0, 'T'
    PRINT_CHAR a0
    
    // Clear timer interrupt by setting mtimecmp to max
    li t0, 0x02004000
    li t1, -1
    sw t1, 0(t0)
    sw t1, 4(t0)
    
    // Print 'P' for pass
    li a0, 'P'
    PRINT_CHAR a0
    
    TEST_HALT
