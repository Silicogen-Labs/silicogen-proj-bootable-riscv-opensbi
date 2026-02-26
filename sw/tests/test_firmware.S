// test_firmware.S
// Comprehensive firmware-like test that exercises features OpenSBI would use
// Tests: CSRs, interrupts, exceptions, counter access, etc.
// Expected output: "FIRMWARE_OK"

#include "test_framework.h"

.section .text
.globl _start

_start:
    // Initialize stack pointer
    li sp, 0x00400000       // Top of RAM
    
    // Print "FIRMWARE_"
    li a0, 'F'
    PRINT_CHAR a0
    li a0, 'I'
    PRINT_CHAR a0
    li a0, 'R'
    PRINT_CHAR a0
    li a0, 'M'
    PRINT_CHAR a0
    li a0, 'W'
    PRINT_CHAR a0
    li a0, 'A'
    PRINT_CHAR a0
    li a0, 'R'
    PRINT_CHAR a0
    li a0, 'E'
    PRINT_CHAR a0
    li a0, '_'
    PRINT_CHAR a0
    
    // Test 1: Read machine ISA
    csrr t0, misa
    bnez t0, test2
    j fail
    
test2:
    // Test 2: Read hart ID
    csrr t0, mhartid
    // Should be 0 for single-hart
    bnez t0, fail
    
    // Test 3: Setup trap vector
1:  auipc t0, %pcrel_hi(trap_handler)
    addi t0, t0, %pcrel_lo(1b)
    csrw mtvec, t0
    csrr t1, mtvec
    bne t0, t1, fail
    
    // Test 4: Access counters
    csrr t0, mcycle
    csrr t1, mcycleh
    // Just verify we can read them
    
    csrr t0, minstret
    csrr t1, minstreth
    
    // Test 5: Test timer interrupt setup
    li t0, 0x02004000
    li t1, 0xFFFFFFFF
    sw t1, 0(t0)        // Set mtimecmp high to prevent immediate interrupt
    sw t1, 4(t0)
    
    // Test 6: Enable interrupts
    li t0, 0x88         // MTIE | MSIE
    csrw mie, t0
    csrr t1, mie
    andi t1, t1, 0x88
    bne t0, t1, fail
    
    // Test 7: Global interrupt enable
    li t0, 0x8
    csrs mstatus, t0
    csrr t1, mstatus
    andi t1, t1, 0x8
    beqz t1, fail
    
    // Test 8: Trigger software interrupt
    li t0, 0x8
    csrw mip, t0
    
    // Should take interrupt soon
    nop
    nop
    nop
    nop
    
    // Should not reach here (will jump to trap_handler)
    j fail

trap_handler:
    // Clear software interrupt
    li t0, 0x8
    csrc mip, t0
    
    // Disable interrupts
    li t0, 0x8
    csrc mstatus, t0
    
    // Print "OK"
    li a0, 'O'
    PRINT_CHAR a0
    li a0, 'K'
    PRINT_CHAR a0
    
    TEST_HALT

fail:
    li a0, 'F'
    PRINT_CHAR a0
    li a0, 'A'
    PRINT_CHAR a0
    li a0, 'I'
    PRINT_CHAR a0
    li a0, 'L'
    PRINT_CHAR a0
    TEST_HALT
