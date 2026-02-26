# Simple illegal instruction test - just print mcause value
.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # mtvec
    
    # Execute illegal instruction
    .word 0xFFFFFFFF
    
    # Should not reach here
    j .

trap_handler:
    # Read mcause
    csrr a0, 0x342
    
    # Print mcause as hex digit (0-9, A-F)
    # Just print the low 4 bits
    andi a1, a0, 0xF
    li a2, 10
    blt a1, a2, print_digit
    addi a1, a1, 55         # 'A' - 10
    j do_print
print_digit:
    addi a1, a1, 48         # '0'
do_print:
    lui a2, 0x10000
    sb a1, 0(a2)
    
    # Skip the illegal instruction
    csrr t0, 0x341
    addi t0, t0, 4
    csrw 0x341, t0
    mret
