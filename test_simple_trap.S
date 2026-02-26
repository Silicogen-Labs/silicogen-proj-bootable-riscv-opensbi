# Ultra-simple trap test - no CSR operations
.section .text
.globl _start

_start:
    li a0, 0x42         # Set a marker value
    ecall               # Trigger trap
    li a1, 0x99         # If we get here, trap failed
    j .                 # Loop

# This will be written to address where we jump on trap
# For now, PC will just go to wherever mtvec points (which is 0x0 by default)
