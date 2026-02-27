.section .text
.globl _start

_start:
    # Direct UART hardware test
    # Write 'H' 'E' 'L' 'L' 'O' to UART at 0x10000000
    
    li t0, 0x10000000    # UART base address
    
    # Write 'H' (0x48)
    li t1, 0x48
    sb t1, 0(t0)
    
    # Write 'E' (0x45)
    li t1, 0x45
    sb t1, 0(t0)
    
    # Write 'L' (0x4C)
    li t1, 0x4C
    sb t1, 0(t0)
    
    # Write 'L' (0x4C)
    li t1, 0x4C
    sb t1, 0(t0)
    
    # Write 'O' (0x4F)
    li t1, 0x4F
    sb t1, 0(t0)
    
    # Write newline (0x0A)
    li t1, 0x0A
    sb t1, 0(t0)
    
    # Infinite loop
1:  j 1b
