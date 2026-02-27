#!/bin/bash
# Create a combined boot image with OpenSBI + DTB

set -e

OPENSBI_HEX="build/opensbi.hex"
DTB_HEX="build/bootble_dtb.hex"
OUTPUT_HEX="build/opensbi_boot.hex"

# DTB address: 0x003F0000 (word address = 0xFC000 = 1032192)
DTB_WORD_ADDR=1032192

if [ ! -f "$OPENSBI_HEX" ]; then
    echo "ERROR: OpenSBI hex not found. Run 'make opensbi' first"
    exit 1
fi

if [ ! -f "$DTB_HEX" ]; then
    echo "ERROR: DTB hex not found"
    exit 1
fi

echo "Creating OpenSBI boot image..."

# Get sizes
OPENSBI_WORDS=$(wc -l < $OPENSBI_HEX)
DTB_WORDS=$(wc -l < $DTB_HEX)

echo "  OpenSBI: $OPENSBI_WORDS words"
echo "  DTB: $DTB_WORDS words at word address $DTB_WORD_ADDR"

# Start with OpenSBI
cp $OPENSBI_HEX $OUTPUT_HEX

# Pad with zeros up to DTB location
CURRENT_WORDS=$OPENSBI_WORDS
PADDING_NEEDED=$((DTB_WORD_ADDR - CURRENT_WORDS))

if [ $PADDING_NEEDED -gt 0 ]; then
    echo "  Adding $PADDING_NEEDED zero-padding words..."
    for ((i=0; i<$PADDING_NEEDED; i++)); do
        echo "00000000" >> $OUTPUT_HEX
    done
fi

# Append DTB
echo "  Appending DTB..."
cat $DTB_HEX >> $OUTPUT_HEX

TOTAL_WORDS=$(wc -l < $OUTPUT_HEX)
TOTAL_KB=$((TOTAL_WORDS * 4 / 1024))

echo "Boot image created: $OUTPUT_HEX"
echo "  Total size: $TOTAL_WORDS words ($TOTAL_KB KB)"
echo ""
echo "DTB will be at physical address 0x003F0000"
echo "Pass this address in register a1 when booting"
