# Simple PC Misalignment Test - Just print mcause

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Try to jump to misaligned address (0x3)
    li t0, 0x3
    jalr x0, t0, 0          # Should trap
    
    # Should not reach here
    li a0, 'X'
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

trap_handler:
    # Read mcause and print as hex digit
    csrr t0, 0x342
    li t1, 10
    blt t0, t1, is_digit
    addi t0, t0, -10
    addi t0, t0, 'A'
    j print_it
is_digit:
    addi t0, t0, '0'
print_it:
    lui t1, 0x10000
    sb t0, 0(t1)
    
    # Print 'P' for pass
    li a0, 'P'
    sb a0, 0(t1)

done:
    j done
