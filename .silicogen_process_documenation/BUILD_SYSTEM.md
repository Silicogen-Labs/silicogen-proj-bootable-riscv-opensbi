# Build System Architecture

## Overview

The build system ensures all components (boot stub, OpenSBI firmware, device tree, and simulator) are properly built and kept in sync.

## Build Components

### 1. Boot Stub (`build/boot_opensbi.hex`)
- **Source**: `sw/tests/boot_opensbi.S`
- **Purpose**: First code executed at address 0x0000_0000
- **Actions**:
  - Sets a0 = 0 (hart ID)
  - Sets a1 = 0x003F0000 (DTB address)
  - Sets a2 = 0 (opaque pointer)
  - Jumps to 0x0000_1000 (OpenSBI entry point)
- **Size**: 6 words (24 bytes)

### 2. OpenSBI Firmware (`build/opensbi_jump.hex`)
- **Source**: `opensbi/` directory (fw_jump configuration)
- **ELF Location**: `opensbi/build/platform/bootble/firmware/fw_jump.elf`
- **Purpose**: RISC-V SBI firmware implementation
- **Load Address**: 0x0000_1000 (word address 1024)
- **Configuration**:
  - Platform: bootble (custom platform in `opensbi/platform/bootble/`)
  - Firmware type: fw_jump (simplest, no runtime relocation)
  - XLEN: 32
  - ISA: rv32ima_zicsr_zifencei
  - ABI: ilp32
  - Text start: 0x00001000
- **Size**: ~65,203 words (~260KB)

### 3. Device Tree Blob (`build/bootble_dtb.hex`)
- **Source**: `bootble.dtb` (compiled device tree)
- **Purpose**: Hardware description for OpenSBI and OS
- **Load Address**: 0x003F_0000 (word address 1,032,192)
- **Size**: 300 words (~1.2KB)

### 4. Final Boot Image (`build/final_boot.hex`)
- **Purpose**: Complete memory image combining all components
- **Structure**:
  ```
  0x00000000 (word 0):         Boot stub (6 words)
  0x00000018 (word 6):         Padding (1018 zeros)
  0x00001000 (word 1024):      OpenSBI firmware (65203 words)
  0x00041BCC (word 66227):     Padding (965965 zeros)
  0x003F0000 (word 1032192):   Device tree (300 words)
  ```
- **Total Size**: 1,032,492 words (~4MB / 8.9MB hex file)

### 5. Verilator Simulator (`build/verilator/Vtb_soc`)
- **Sources**: RTL files + testbench + C++ sim_main
- **Configuration**: TEST_PROGRAM define points to boot image
- **Memory Init**: Uses $readmemh() to load boot image at simulation start

## Build Targets

### Quick Start
```bash
make rebuild       # Clean and rebuild everything
./build/verilator/Vtb_soc  # Run simulation
```

### Individual Targets

#### `make boot-image`
Builds the complete boot image by:
1. Compiling boot stub from `sw/tests/boot_opensbi.S`
2. Building OpenSBI fw_jump (if not already built)
3. Converting fw_jump.elf to hex format
4. Converting DTB to hex format
5. Combining all components into `build/final_boot.hex`

**Dependencies**:
- Boot stub depends on: `sw/tests/boot_opensbi.S`
- OpenSBI depends on: `opensbi/` source tree, `bootble.dtb`
- DTB depends on: `bootble.dtb` (pre-compiled)
- Final image depends on: all of the above

#### `make sim-boot`
Builds the Verilator simulator configured for OpenSBI boot:
1. Ensures `build/final_boot.hex` exists (triggers boot-image if needed)
2. Compiles RTL and testbench with Verilator
3. Sets TEST_PROGRAM define to absolute path of `build/final_boot.hex`
4. Links C++ simulation wrapper

**Output**: `build/verilator/Vtb_soc` executable

#### `make verify-build`
Checks that all required files exist:
- ✓ Boot stub hex
- ✓ OpenSBI fw_jump hex
- ✓ DTB hex  
- ✓ Final boot image
- ✓ Simulator binary

Also displays file sizes for verification.

#### `make rebuild`
Complete rebuild from scratch:
```bash
make clean         # Remove build artifacts
make boot-image    # Build boot image
make sim-boot      # Build simulator
```

#### `make clean`
Removes:
- `build/` directory (all hex files, binaries, Verilator output)
- VCD waveform files

**Preserves**:
- OpenSBI build artifacts (in `opensbi/build/`)
- Source files

#### `make distclean`
Deep clean including OpenSBI:
```bash
make clean
make -C opensbi distclean PLATFORM=bootble
```

## Build Dependencies Graph

```
build/final_boot.hex
├── build/boot_opensbi.hex
│   └── sw/tests/boot_opensbi.S
├── build/opensbi_jump.hex
│   └── opensbi/build/platform/bootble/firmware/fw_jump.elf
│       ├── opensbi/ source tree
│       └── bootble.dtb
└── build/bootble_dtb.hex
    └── bootble.dtb

build/verilator/Vtb_soc
├── build/final_boot.hex (via TEST_PROGRAM define)
├── RTL sources (rtl/*/*.sv)
├── Testbench (sim/testbenches/tb_soc.sv)
└── C++ wrapper (sim/sim_main.cpp)
```

## Key Makefile Variables

```makefile
# Boot image components
OPENSBI_FW_JUMP_ELF = opensbi/build/platform/bootble/firmware/fw_jump.elf
OPENSBI_JUMP_HEX    = build/opensbi_jump.hex
BOOT_STUB_HEX       = build/boot_opensbi.hex
DTB_HEX             = build/bootble_dtb.hex
FINAL_BOOT_HEX      = build/final_boot.hex

# Test program override
TEST      ?= hello
TEST_HEX  ?= build/$(TEST).hex

# For OpenSBI boot, set TEST=final_boot
# This makes TEST_HEX = build/final_boot.hex
```

## Important Build Notes

### 1. Absolute Paths Required
The Makefile uses absolute paths for TEST_PROGRAM define:
```makefile
-DTEST_PROGRAM=\"$(shell pwd)/$(TEST_HEX)\"
```

**Why**: Verilator's `$readmemh()` is evaluated during simulation initialization, and relative paths may not work correctly depending on working directory.

### 2. OpenSBI Build Configuration
OpenSBI must be built with specific flags:
```makefile
PLATFORM=bootble
CROSS_COMPILE=riscv64-linux-gnu-
PLATFORM_RISCV_XLEN=32
PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei
PLATFORM_RISCV_ABI=ilp32
FW_TEXT_START=0x00001000
FW_JUMP=y
FW_JUMP_ADDR=0x00001000
FW_FDT_PATH=$(pwd)/bootble.dtb
```

These are hardcoded in the Makefile to ensure consistency.

### 3. Build Order
Components MUST be built in this order:
1. Boot stub (standalone)
2. OpenSBI firmware (requires DTB path)
3. DTB hex conversion
4. Final boot image (combines all)
5. Simulator (requires final boot image)

The Makefile dependencies handle this automatically.

### 4. Incremental Builds
- OpenSBI: Only rebuilt if source changes (handled by OpenSBI's Makefile)
- Boot stub: Rebuilt if `.S` file changes
- Final image: Rebuilt if any component changes
- Simulator: Rebuilt if RTL, testbench, or TEST_HEX path changes

## Troubleshooting

### Problem: Simulator shows empty memory
**Symptoms**: 
```
MEM[0x00000000] = 0x00000000
...
[0] TRAP #0: pc=0x00000000 cause=2(EXC)
```

**Cause**: Boot image not loaded

**Solution**:
```bash
make verify-build  # Check which files are missing
make boot-image    # Rebuild boot image if needed
make sim-boot      # Rebuild simulator with correct path
```

### Problem: "File not found" warning from $readmemh
**Symptoms**:
```
%Warning: /path/to/file.hex:0: $readmem file not found
```

**Cause**: TEST_HEX file doesn't exist or path is wrong

**Solution**:
```bash
ls -la build/final_boot.hex  # Verify file exists
make boot-image              # Rebuild if missing
```

### Problem: Old boot image still being used
**Symptoms**: Changes to boot stub or OpenSBI not reflected in simulation

**Solution**:
```bash
make clean       # Remove all build artifacts
make rebuild     # Rebuild from scratch
```

### Problem: OpenSBI build fails
**Symptoms**: Error during `make boot-image`

**Solution**:
```bash
make distclean   # Clean OpenSBI build
# Check that bootble.dtb exists
ls -la bootble.dtb
# Rebuild
make boot-image
```

## Verification Steps

After a clean build, verify:

1. **Files exist**:
   ```bash
   make verify-build
   ```

2. **Boot image has correct size**:
   ```bash
   wc -l build/final_boot.hex
   # Should show: 1032492 words
   ```

3. **Boot stub is at start**:
   ```bash
   head -6 build/final_boot.hex
   # Should show boot stub instructions
   ```

4. **OpenSBI is at offset 0x1000**:
   ```bash
   sed -n '1025p' build/final_boot.hex
   # Should show OpenSBI first instruction (not 00000000)
   ```

5. **Simulator loads memory**:
   ```bash
   timeout 2 ./build/verilator/Vtb_soc 2>&1 | grep "MEMCHECK"
   # Should show non-zero values
   ```

## Best Practices

1. **Always verify after rebuild**:
   ```bash
   make rebuild && make verify-build
   ```

2. **Check simulation loads correctly**:
   ```bash
   timeout 5 ./build/verilator/Vtb_soc 2>&1 | head -30
   # Look for MEMCHECK lines showing non-zero values
   ```

3. **Keep build log**:
   ```bash
   make rebuild 2>&1 | tee build.log
   ```

4. **When in doubt, clean rebuild**:
   ```bash
   make distclean && make rebuild
   ```

## File Sizes Reference

For a successful build:
- `build/boot_opensbi.hex`: 6 lines
- `build/opensbi_jump.hex`: ~65,203 lines
- `build/bootble_dtb.hex`: 300 lines
- `build/final_boot.hex`: 1,032,492 lines (~8.9MB file)
- `build/verilator/Vtb_soc`: ~320KB binary

If sizes differ significantly, rebuild from scratch.
