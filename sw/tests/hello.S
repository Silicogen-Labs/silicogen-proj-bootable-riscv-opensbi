# Simple RISC-V test program
# Prints "Hello RISC-V!" to UART and loops

.section .text
.globl _start

_start:
    # Set up stack pointer (top of 4MB RAM)
    li sp, 0x00400000
    
    # Print "Hello RISC-V!\n" via UART
    # Load string address directly (it's at 0xFC in our layout)
    li a0, 0xFC
    call print_string
    
    # Infinite loop
done:
    j done

# Function: print_string
# Input: a0 = pointer to null-terminated string
# Uses: a0 (string ptr), a1 (UART base), t0 (char), t1 (status)
print_string:
    li a1, 0x10000000       # UART base address
    
print_loop:
    lbu t0, 0(a0)           # Load byte from string
    beqz t0, print_done     # If null terminator, done
    
    # Wait for UART TX ready (LSR[5] = THRE)
wait_uart:
    lbu t1, 5(a1)           # Read LSR (offset 5)
    andi t1, t1, 0x20       # Check bit 5 (THRE)
    beqz t1, wait_uart      # Wait until ready
    
    # Send character
    sb t0, 0(a1)            # Write to THR (offset 0)
    
    # Next character
    addi a0, a0, 1
    j print_loop
    
print_done:
    ret

# Pad to 0x100 where we'll place our string
.org 0x100
hello_msg:
    .ascii "Hello RISC-V!\n"
    .byte 0                 # Null terminator
