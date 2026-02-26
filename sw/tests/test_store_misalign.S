# Test Store Address Misalignment Exception
# Simple test to verify store misalignment detection

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Try to store halfword to odd address
    li t0, 0x3001           # Odd address (misaligned for halfword)
    li t1, 0x1234
    sh t1, 0(t0)            # Should trap with mcause=6
    
    # Should not reach here
    li a0, 'X'
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

trap_handler:
    # Read mcause
    csrr t0, 0x342
    
    # Check if mcause == 6 (store address misaligned)
    li t1, 6
    bne t0, t1, wrong_cause
    
    # Read mtval - should be 0x3001
    csrr t2, 0x343
    li t3, 0x3001
    bne t2, t3, wrong_mtval
    
    # All checks passed - print 'P'
    li a0, 'P'
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

wrong_cause:
    # Print mcause as hex digit
    li t1, 10
    blt t0, t1, is_digit
    addi t0, t0, -10
    addi t0, t0, 'A'
    j print_cause
is_digit:
    addi t0, t0, '0'
print_cause:
    lui t1, 0x10000
    sb t0, 0(t1)
    j done

wrong_mtval:
    li a0, 'V'
    lui t1, 0x10000
    sb a0, 0(t1)

done:
    j done
