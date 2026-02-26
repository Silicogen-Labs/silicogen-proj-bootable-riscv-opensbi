# Simple Load Misalignment Test - Just check if trap occurs
# Print mepc value as ASCII hex digit

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Try to load halfword from odd address
    li t0, 0x3001           # Odd address
    lh t1, 0(t0)            # Should trap
    
    # Should not reach here
    li a0, 'X'
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

trap_handler:
    # Read mcause
    csrr t0, 0x342
    
    # Print mcause as hex digit (0-9, A-F)
    li t1, 10
    blt t0, t1, is_digit
    # It's A-F
    addi t0, t0, -10
    addi t0, t0, 'A'
    j print_it
is_digit:
    # It's 0-9
    addi t0, t0, '0'
print_it:
    lui t1, 0x10000
    sb t0, 0(t1)
    
    # Print 'P' to indicate test passed
    li a0, 'P'
    sb a0, 0(t1)

done:
    j done
