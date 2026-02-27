#!/bin/bash
# Create final boot image: OpenSBI at 0x0 + DTB at 0x3F0000
#
# Memory layout:
# 0x00000000 (word 0):       OpenSBI firmware (FW_TEXT_START=0x0, _fw_start=0x0)
# 0x00040000 (word 262144):  OpenSBI RW data (_fw_rw_start, fw_rw_offset=0x40000=2^18 ✓)
# 0x003F0000 (word 1032192): Device tree blob (FW_JUMP_FDT_ADDR=0x003F0000)
#
# fw_start=0x0, fw_rw_offset=0x40000: alignment check 0x0 & 0x3FFFF == 0 ✓
# No boot stub needed: OpenSBI runs directly from reset vector 0x0.
# DTB address is hardcoded via FW_JUMP_FDT_ADDR at build time.

set -e

OPENSBI_HEX="build/opensbi_jump.hex"
DTB_HEX="build/bootble_dtb.hex"
OUTPUT_HEX="build/final_boot.hex"

DTB_WORD_ADDR=1032192   # 0x003F0000 / 4

echo "Creating final boot image with:"
echo "  OpenSBI at   0x00000000 (FW_TEXT_START=0x0)"
echo "  DTB at       0x003F0000"
echo ""

# Check files exist
for file in "$OPENSBI_HEX" "$DTB_HEX"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: $file not found"
        exit 1
    fi
done

OPENSBI_WORDS=$(wc -l < $OPENSBI_HEX)
DTB_WORDS=$(wc -l < $DTB_HEX)

echo "Component sizes:"
echo "  OpenSBI:   $OPENSBI_WORDS words ($(( OPENSBI_WORDS * 4 / 1024 )) KB)"
echo "  DTB:       $DTB_WORDS words"
echo ""

# OpenSBI starts at address 0x0
cp $OPENSBI_HEX $OUTPUT_HEX

# Check OpenSBI doesn't overflow into DTB
if [ $OPENSBI_WORDS -gt $DTB_WORD_ADDR ]; then
    echo "ERROR: OpenSBI ($OPENSBI_WORDS words) overflows into DTB area ($DTB_WORD_ADDR words)"
    exit 1
fi

# Pad to DTB location
PADDING=$((DTB_WORD_ADDR - OPENSBI_WORDS))
echo "Padding $PADDING words to reach DTB at 0x3F0000..."
for ((i=0; i<$PADDING; i++)); do
    echo "00000000" >> $OUTPUT_HEX
done

# Append DTB
echo "Adding device tree..."
cat $DTB_HEX >> $OUTPUT_HEX

TOTAL_WORDS=$(wc -l < $OUTPUT_HEX)
TOTAL_KB=$((TOTAL_WORDS * 4 / 1024))

echo ""
echo "Boot image created: $OUTPUT_HEX"
echo "  Total: $TOTAL_WORDS words ($TOTAL_KB KB)"
echo ""
echo "Memory layout:"
echo "  0x00000000: OpenSBI entry (_fw_start=0x0, FW_TEXT_START=0x0)"
echo "  0x00040000: OpenSBI RW data (_fw_rw_start, fw_rw_offset=0x40000=2^18 ✓)"
echo "  0x003F0000: DTB (FW_JUMP_FDT_ADDR=0x003F0000)"
echo ""
echo "fw_start=0x0 & (fw_rw_offset-1)=0x3FFFF = 0 ✓ (alignment check passes)"
