#!/usr/bin/env python3
"""
patch_opensbi_relocs.py - Pre-patch R_RISCV_RELATIVE relocations in an OpenSBI binary.

OpenSBI fw_dynamic is a PIE linked from base 0x0.  When loaded at address
LOAD_OFFSET (e.g. 0x1000), the runtime relocation loop computes:
    reloc_delta = runtime_fw_start - FW_TEXT_START

Because FW_TEXT_START == LOAD_OFFSET, reloc_delta == 0 instead of LOAD_OFFSET.
This script pre-applies the missing LOAD_OFFSET to every R_RISCV_RELATIVE entry
so the runtime loop (which adds 0) produces correct results.

Usage:
    python3 patch_opensbi_relocs.py <elf_file> <bin_file> <output_bin> [load_offset]

Arguments:
    elf_file    : OpenSBI fw_dynamic ELF (for relocation metadata)
    bin_file    : Flat binary to patch (fw_dynamic.bin loaded at load_offset)
    output_bin  : Patched binary output path
    load_offset : Load address of binary in RAM (default 0x1000)
"""

import sys
import struct
import os

def read_elf_relocations(elf_path):
    """Read all R_RISCV_RELATIVE relocations from the ELF .rela.dyn section."""
    with open(elf_path, 'rb') as f:
        data = f.read()

    # Parse ELF header (32-bit little-endian)
    assert data[0:4] == b'\x7fELF', "Not an ELF file"
    assert data[4] == 1, "Expected 32-bit ELF"
    assert data[5] == 1, "Expected little-endian ELF"

    e_shoff  = struct.unpack_from('<I', data, 0x20)[0]
    e_shentsize = struct.unpack_from('<H', data, 0x2e)[0]
    e_shnum  = struct.unpack_from('<H', data, 0x30)[0]
    e_shstrndx = struct.unpack_from('<H', data, 0x32)[0]

    # Read section headers
    sections = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        sh = struct.unpack_from('<IIIIIIIIII', data, off)
        sections.append({
            'sh_name': sh[0], 'sh_type': sh[1], 'sh_flags': sh[2],
            'sh_addr': sh[3], 'sh_offset': sh[4], 'sh_size': sh[5],
            'sh_link': sh[6], 'sh_info': sh[7], 'sh_addralign': sh[8],
            'sh_entsize': sh[9],
        })

    # Find shstrtab
    shstr_sec = sections[e_shstrndx]
    shstrtab = data[shstr_sec['sh_offset']:shstr_sec['sh_offset'] + shstr_sec['sh_size']]

    def sec_name(s):
        nul = shstrtab.index(b'\x00', s['sh_name'])
        return shstrtab[s['sh_name']:nul].decode()

    # Find .rela.dyn  (SHT_RELA = 4)
    rela_sec = None
    for s in sections:
        if s['sh_type'] == 4 and sec_name(s) == '.rela.dyn':
            rela_sec = s
            break

    if rela_sec is None:
        print("WARNING: No .rela.dyn section found, nothing to patch", file=sys.stderr)
        return []

    # Parse RELA entries (12 bytes each: offset, info, addend)
    relocs = []
    n = rela_sec['sh_size'] // 12
    for i in range(n):
        off = rela_sec['sh_offset'] + i * 12
        r_offset, r_info, r_addend = struct.unpack_from('<III', data, off)
        r_type = r_info & 0xff
        # R_RISCV_RELATIVE = 3
        if r_type == 3:
            relocs.append((r_offset, r_addend))

    return relocs


def patch_binary(bin_path, output_path, relocs, load_offset):
    """
    For each reloc (elf_addr, addend):
      - binary offset = elf_addr  (ELF vaddr maps directly to bin offset, since ELF base=0)
      - correct value = addend + load_offset     (the runtime should store this)
      - OpenSBI runtime will add 0 (wrong) so we pre-add load_offset
    """
    with open(bin_path, 'rb') as f:
        data = bytearray(f.read())

    bin_size = len(data)
    patched = 0
    skipped = 0

    for elf_addr, addend in relocs:
        bin_off = elf_addr  # ELF vaddr IS the binary offset (since ELF link base = 0x0)
        if bin_off + 4 > bin_size:
            print(f"  SKIP reloc @ ELF 0x{elf_addr:x}: bin offset 0x{bin_off:x} out of range (bin_size=0x{bin_size:x})", file=sys.stderr)
            skipped += 1
            continue

        # What's currently there (should be 0 for un-relocated PIE data)
        current = struct.unpack_from('<I', data, bin_off)[0]
        # What it should become
        correct = (addend + load_offset) & 0xFFFFFFFF

        struct.pack_into('<I', data, bin_off, correct)
        patched += 1

        if os.environ.get('VERBOSE'):
            print(f"  reloc @ ELF 0x{elf_addr:08x} bin+0x{bin_off:08x}: 0x{current:08x} -> 0x{correct:08x}")

    with open(output_path, 'wb') as f:
        f.write(data)

    return patched, skipped


def bin_to_hex(bin_path, hex_path):
    """Convert flat binary to one-word-per-line hex (little-endian 32-bit words)."""
    with open(bin_path, 'rb') as f:
        data = f.read()

    # Pad to word boundary
    pad = (4 - len(data) % 4) % 4
    data = data + b'\x00' * pad

    with open(hex_path, 'w') as f:
        for i in range(0, len(data), 4):
            word = struct.unpack_from('<I', data, i)[0]
            f.write(f'{word:08x}\n')


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)

    elf_file   = sys.argv[1]
    bin_file   = sys.argv[2]
    output_bin = sys.argv[3]
    load_offset = int(sys.argv[4], 0) if len(sys.argv) > 4 else 0x1000

    print(f"Patching OpenSBI relocations:")
    print(f"  ELF:         {elf_file}")
    print(f"  Input bin:   {bin_file}")
    print(f"  Output bin:  {output_bin}")
    print(f"  Load offset: 0x{load_offset:x}")

    relocs = read_elf_relocations(elf_file)
    print(f"  Found {len(relocs)} R_RISCV_RELATIVE relocations")

    patched, skipped = patch_binary(bin_file, output_bin, relocs, load_offset)
    print(f"  Patched {patched} entries, skipped {skipped}")

    # Also emit .hex if output ends in .bin
    if output_bin.endswith('.bin'):
        hex_out = output_bin[:-4] + '.hex'
        bin_to_hex(output_bin, hex_out)
        hex_lines = sum(1 for _ in open(hex_out))
        print(f"  Hex output:  {hex_out} ({hex_lines} words)")

    print("Done.")


if __name__ == '__main__':
    main()
