# Boot stub for OpenSBI
# This minimal bootloader initializes registers and jumps to OpenSBI
# Place this at 0x0, OpenSBI firmware starts at 0x1000

.section .text
.global _start

_start:
    # Setup OpenSBI entry parameters
    # a0 = hart ID (always 0 for single-core)
    # a1 = device tree blob address (DTB at 0x003F0000)
    # a2 = dynamic info pointer (0 = use defaults)
    
    li a0, 0                # Hart ID = 0
    lui a1, 0x3F0          # DTB at 0x003F0000  
    li a2, 0                # No dynamic info
    
    # Jump to OpenSBI entry point at 0x1000
    lui t0, 0x1             # t0 = 0x1000
    jr t0                   # Jump to OpenSBI

    # Should never reach here
_hang:
    j _hang
