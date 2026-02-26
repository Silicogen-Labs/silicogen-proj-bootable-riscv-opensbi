# Test Instruction Address Misalignment Exception
# Tests that jumps to non-4-byte-aligned addresses trap

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Try to jump to misaligned address (0x3 - not 4-byte aligned)
    li t0, 0x3
    jalr x0, t0, 0          # Jump to address 0x3 - should trap
    
    # Should not reach here
    li a0, 'X'
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

trap_handler:
    # Read mcause
    csrr t0, 0x342
    
    # Check if mcause == 0 (instruction address misaligned)
    li t1, 0
    bne t0, t1, wrong_cause
    
    # Read mtval - should be 0x3 (the misaligned PC)
    csrr t2, 0x343
    li t3, 0x3
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
