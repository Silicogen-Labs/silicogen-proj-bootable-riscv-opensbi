#!/bin/bash
# Convert OpenSBI firmware to Verilog hex format

set -e

OPENSBI_ELF="opensbi/build/platform/bootble/firmware/fw_dynamic.elf"
OUTPUT_BIN="build/opensbi.bin"
OUTPUT_HEX="build/opensbi.hex"

if [ ! -f "$OPENSBI_ELF" ]; then
    echo "ERROR: OpenSBI firmware not found at $OPENSBI_ELF"
    echo "Please build OpenSBI first"
    exit 1
fi

echo "Converting OpenSBI firmware to hex format..."

# Create build directory if it doesn't exist
mkdir -p build

# Convert ELF to binary
echo "Step 1: Converting ELF to binary..."
riscv64-linux-gnu-objcopy -O binary $OPENSBI_ELF $OUTPUT_BIN

# Convert binary to Verilog hex format (32-bit words, little-endian)
echo "Step 2: Converting binary to hex..."
od -An -tx4 -w4 -v $OUTPUT_BIN | awk '{print $1}' > $OUTPUT_HEX

# Show size
BIN_SIZE=$(stat -c%s $OUTPUT_BIN)
HEX_LINES=$(wc -l < $OUTPUT_HEX)

echo "Conversion complete!"
echo "  Binary size: $BIN_SIZE bytes"
echo "  Hex file: $HEX_LINES words (32-bit)"
echo "  Output: $OUTPUT_HEX"

# Show first few lines
echo ""
echo "First 16 words of firmware:"
head -16 $OUTPUT_HEX
