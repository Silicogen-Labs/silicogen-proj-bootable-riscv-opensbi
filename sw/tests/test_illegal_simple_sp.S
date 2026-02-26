# Simple illegal instruction test - with stack pointer setup
.section .text
.globl _start

_start:
    # ADDED: Set up stack pointer, which seemed to cause issues
    lui sp, 0x400

    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0
    
    # Execute illegal instruction
    .word 0xFFFFFFFF
    
    j .

trap_handler:
    # Read mcause and print it
    csrr a0, 0x342
    andi a1, a0, 0xF
    li a2, 10
    blt a1, a2, print_digit
    addi a1, a1, 55
    j do_print
print_digit:
    addi a1, a1, 48
do_print:
    lui a2, 0x10000
    sb a1, 0(a2)
    
    j .
