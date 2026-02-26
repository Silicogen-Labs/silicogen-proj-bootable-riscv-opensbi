# Test Load Address Misalignment Exception
# Verifies that misaligned loads trigger traps with correct mcause

.section .text
.globl _start

_start:
    # Set up trap handler
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Test 1: LH (load halfword) from odd address - should trap
    li t0, 0x3001           # Odd address (misaligned for halfword)
    lh t1, 0(t0)            # This should trap with mcause=4
    
    # Should not reach here
    li a0, 'X'
    j fail

test2:
    # Test 2: LW (load word) from address not 4-byte aligned - should trap
    li t0, 0x3002           # Address aligned to 2 but not 4
    lw t1, 0(t0)            # This should trap with mcause=4
    
    # Should not reach here
    li a0, 'Y'
    j fail

pass:
    # All tests passed - print 'P'
    lui t1, 0x10000
    li a0, 'P'
    sb a0, 0(t1)
    j done

fail:
    # Test failed - print failure character (X or Y)
    lui t1, 0x10000
    sb a0, 0(t1)
    j done

# Infinite loop
done:
    j done

# Trap handler
trap_handler:
    # Read mcause - should be 4 for load address misaligned
    csrr t0, 0x342          # mcause
    
    # Read mtval - should contain the misaligned address
    csrr t1, 0x343          # mtval
    
    # Read mepc to determine which test we're in
    csrr t2, 0x341          # mepc
    
    # Check if mcause == 4 (load address misaligned)
    li t3, 4
    bne t0, t3, fail_cause
    
    # Determine which test based on mepc
    li t4, 0x14             # Address of lh instruction in test1
    beq t2, t4, test1_trap
    
    li t4, 0x28             # Address of lw instruction in test2
    beq t2, t4, test2_trap
    
    # Unknown trap location
    li a0, 'U'
    j fail

test1_trap:
    # Verify mtval contains 0x3001
    li t3, 0x3001
    bne t1, t3, fail_mtval
    
    # Check mepc - should be 0x14 (address of lh instruction)
    li t4, 0x14
    bne t2, t4, fail_mepc
    
    # Test 1 passed, skip over the failing instruction and go to test2
    la t0, test2
    csrw 0x341, t0
    mret

test2_trap:
    # Verify mtval contains 0x3002
    li t3, 0x3002
    bne t1, t3, fail_mtval
    
    # Check mepc - should be 0x28 (address of lw instruction)
    li t4, 0x28
    bne t2, t4, fail_mepc
    
    # Test 2 passed, go to pass label
    la t0, pass
    csrw 0x341, t0
    mret
    
fail_mepc:
    # Wrong mepc
    li a0, 'M'
    lui t3, 0x10000
    sb a0, 0(t3)
    j done

fail_cause:
    # Wrong mcause
    li a0, 'C'
    lui t3, 0x10000
    sb a0, 0(t3)
    j done

fail_mtval:
    # Wrong mtval
    li a0, 'V'
    lui t3, 0x10000
    sb a0, 0(t3)
    j done
