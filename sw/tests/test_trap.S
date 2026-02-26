# Test ECALL and EBREAK trap handling
# Tests basic exception entry and MRET return

.section .text
.globl _start

_start:
    # Set up stack pointer
    lui sp, 0x400
    
    # Initialize trap handler address in mtvec
    # mtvec = 0x305
    la t0, trap_handler
    csrw 0x305, t0          # Write to mtvec
    
    # Test 1: ECALL should trap
    li a0, 1                # Test ID
    ecall                   # This should jump to trap_handler
    
    # If we get here, ECALL worked and MRET returned us
    li a1, 0x11             # Success marker for ECALL
    
    # Test 2: EBREAK should trap
    li a0, 2                # Test ID
    ebreak                  # This should jump to trap_handler
    
    # If we get here, EBREAK worked
    li a2, 0x22             # Success marker for EBREAK
    
    # Test 3: Read trap cause from previous EBREAK
    # mcause for EBREAK should be 3
    csrr a3, 0x342          # Read mcause
    
    # Print success message to UART
    lui a0, 0x10000         # UART base
    li a1, 'O'
    sb a1, 0(a0)
    li a1, 'K'
    sb a1, 0(a0)
    li a1, '\n'
    sb a1, 0(a0)
    
    # Infinite loop
done:
    j done

# Trap handler - handles ECALL and EBREAK
trap_handler:
    # Save context (in real code, would save all registers)
    # For this test, just increment a counter and return
    
    # Read mcause to see what trapped
    csrr t0, 0x342          # mcause
    
    # Read mepc (return address)
    csrr t1, 0x341          # mepc
    
    # Increment mepc by 4 to skip the trapping instruction
    addi t1, t1, 4
    csrw 0x341, t1          # Write back to mepc
    
    # Return from trap
    mret

.section .data
msg:
    .string "Trap test\n"
