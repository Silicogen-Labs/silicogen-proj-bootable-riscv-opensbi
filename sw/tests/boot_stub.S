/* boot_stub.S
 * Minimal M-mode boot stub placed at 0x0.
 *
 * Layout:
 *   0x00: j _start           (jump over the struct)
 *   0x04: padding (3 words)
 *   0x10: fw_dynamic_info struct (6 words = 24 bytes)
 *   0x28: _start code begins here
 *
 * Register convention on entry to fw_dynamic:
 *   a0 = boot hart ID (0)
 *   a1 = address of FDT (0 = let OpenSBI use its embedded FDT)
 *   a2 = address of fw_dynamic_info struct = 0x10
 */

#define OPENSBI_OFFSET  0x1000

    .section .text.start, "ax", @progbits
    .global _start
    .align 2

    /* Word 0: jump over struct to _start code */
    j       _start

    /* Words 1-3: padding */
    .word   0x00000000
    .word   0x00000000
    .word   0x00000000

    /* fw_dynamic_info at fixed address 0x10 */
fw_dynamic_info:
    .word   0x4942534f      /* magic   = 'OSBI' */
    .word   0x00000002      /* version = 2 */
    .word   0x00000000      /* next_addr = 0 (no next stage) */
    .word   0x00000001      /* next_mode = 1 (S-mode) */
    .word   0x00000000      /* options = 0 */
    .word   0xffffffff      /* boot_hart = -1 (use lottery) */

_start:
    li      a0, 0               /* hart ID = 0 */
    li      a1, 0               /* FDT ptr = 0 (OpenSBI uses embedded FDT) */
    li      a2, 0x10            /* fw_dynamic_info is at address 0x10 */
    li      t0, OPENSBI_OFFSET  /* OpenSBI entry at 0x1000 */
    jr      t0
