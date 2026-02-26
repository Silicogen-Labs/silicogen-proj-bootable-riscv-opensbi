# Test Illegal Instruction Exception
# Verifies that invalid opcodes trigger traps with mcause=2

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Execute illegal instruction (all 1's)
    .word 0xFFFFFFFF
    
    # If we get here, the trap handler returned successfully
    # Print 'P' for Pass
    lui t1, 0x10000
    li a0, 'P'
    sb a0, 0(t1)
    
    # Infinite loop
done:
    j done

# Trap handler
trap_handler:
    # Read mcause - should be 2 for illegal instruction
    csrr t0, 0x342          # mcause
    
    # Read mtval - should contain the illegal instruction
    csrr t1, 0x343          # mtval
    
    # Verify mcause == 2
    li t2, 2
    bne t0, t2, fail_cause
    
    # Verify mtval == 0xFFFFFFFF
    li t2, 0xFFFFFFFF
    bne t1, t2, fail_mtval
    
    # Success - skip over the illegal instruction
    csrr t0, 0x341          # Read mepc
    addi t0, t0, 4
    csrw 0x341, t0
    
    mret

fail_cause:
    # Print 'C' for cause error
    lui t3, 0x10000
    li t4, 'C'
    sb t4, 0(t3)
    j done

fail_mtval:
    # Print 'V' for mtval error
    lui t3, 0x10000
    li t4, 'V'
    sb t4, 0(t3)
    j done
