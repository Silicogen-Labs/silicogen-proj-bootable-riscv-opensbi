# Test if CSRR works for different destination registers
.section .text
.globl _start
_start:
    la t0, trap_handler
    csrw mtvec, t0
    .word 0xFFFFFFFF
    j .

trap_handler:
    # Use t0 (x5) as destination, which failed in the other test
    csrr t0, mcause 
    
    # Print it
    andi t1, t0, 0xF
    li t2, 10
    blt t1, t2, print_digit
    addi t1, t1, 55
    j do_print
print_digit:
    addi t1, t1, 48
do_print:
    lui t2, 0x10000
    sb t1, 0(t2)
    j .
