# RISC-V SoC Makefile for Verilator Simulation

# Directories
RTL_DIR = rtl
SIM_DIR = sim
BUILD_DIR = build
WAVE_DIR = $(SIM_DIR)/waveforms
SW_DIR = sw
TEST_DIR = $(SW_DIR)/tests

# Tools
VERILATOR = verilator
RISCV_PREFIX = riscv64-linux-gnu-
RISCV_CC = $(RISCV_PREFIX)gcc
RISCV_OBJCOPY = $(RISCV_PREFIX)objcopy
RISCV_OBJDUMP = $(RISCV_PREFIX)objdump

# Verilator flags
VFLAGS = --cc --exe --build --trace --no-timing
VFLAGS += -Wall -Wno-fatal
VFLAGS += --top-module tb_soc
VFLAGS += -I$(RTL_DIR)/core
VFLAGS += -I$(RTL_DIR)/bus
VFLAGS += -I$(RTL_DIR)/peripherals
VFLAGS += -I$(RTL_DIR)/soc
VFLAGS += --Mdir $(BUILD_DIR)/verilator
VFLAGS += -CFLAGS "-I$(shell pwd)"
VFLAGS += -LDFLAGS "-L$(shell pwd)"

# RTL source files
RTL_SOURCES = \
	$(RTL_DIR)/core/riscv_defines.vh \
	$(RTL_DIR)/core/register_file.sv \
	$(RTL_DIR)/core/alu.sv \
	$(RTL_DIR)/core/muldiv.sv \
	$(RTL_DIR)/core/decoder.sv \
	$(RTL_DIR)/core/csr_file.sv \
	$(RTL_DIR)/core/cpu_core.sv \
	$(RTL_DIR)/bus/simple_bus.sv \
	$(RTL_DIR)/peripherals/ram.sv \
	$(RTL_DIR)/peripherals/uart_16550.sv \
	$(RTL_DIR)/soc/riscv_soc.sv

# Testbench files
TB_SOURCES = $(SIM_DIR)/testbenches/tb_soc.sv

# C++ simulation files
CPP_SOURCES = $(SIM_DIR)/sim_main.cpp

# Software test files (can override with TEST=test_name)
TEST ?= hello
HEX_FILE ?= $(BUILD_DIR)/$(TEST).hex
TEST_PROGRAM = $(TEST_DIR)/$(TEST).S
TEST_ELF = $(BUILD_DIR)/$(TEST).elf
TEST_BIN = $(BUILD_DIR)/$(TEST).bin
TEST_HEX = $(HEX_FILE)
TEST_DUMP = $(BUILD_DIR)/$(TEST).dump

# RISC-V compiler flags
RISCV_CFLAGS = -march=rv32ima_zicsr -mabi=ilp32 -nostdlib -nostartfiles
RISCV_CFLAGS += -Ttext=0x00000000 -static -fno-common -fno-builtin
RISCV_CFLAGS += -I$(TEST_DIR)  # Include test directory for test_framework.h
RISCV_LDFLAGS = -Ttext=0x00000000 -nostdlib -static

# Default target
.PHONY: all
all: sim

# Create necessary directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(WAVE_DIR):
	mkdir -p $(WAVE_DIR)

# Compile test program (with C preprocessor for .include support)
$(TEST_ELF): $(TEST_PROGRAM) | $(BUILD_DIR)
	$(RISCV_CC) -x assembler-with-cpp $(RISCV_CFLAGS) $(RISCV_LDFLAGS) -o $@ $<

$(TEST_BIN): $(TEST_ELF)
	$(RISCV_OBJCOPY) -O binary --remove-section=.note.gnu.build-id $< $@

$(TEST_HEX): $(TEST_BIN)
	od -An -tx4 -w4 -v $< | awk '{print $$1}' > $@

$(TEST_DUMP): $(TEST_ELF)
	$(RISCV_OBJDUMP) -d $< > $@

# Build test program
.PHONY: sw
sw: $(TEST_HEX) $(TEST_DUMP)
	@echo "=== Test program built ==="
	@echo "ELF: $(TEST_ELF)"
	@echo "HEX: $(TEST_HEX)"
	@echo "DUMP: $(TEST_DUMP)"

# OpenSBI firmware files
OPENSBI_DIR = opensbi
OPENSBI_FW_JUMP_ELF = $(OPENSBI_DIR)/build/platform/bootble/firmware/fw_jump.elf
OPENSBI_JUMP_BIN = $(BUILD_DIR)/opensbi_jump.bin
OPENSBI_JUMP_HEX = $(BUILD_DIR)/opensbi_jump.hex

# Boot stub and final image
BOOT_STUB_HEX = $(BUILD_DIR)/boot_opensbi.hex
DTB_HEX = $(BUILD_DIR)/bootble_dtb.hex
FINAL_BOOT_HEX = $(BUILD_DIR)/final_boot.hex

# DTB source
DTB_SOURCE = dts/bootble.dtb

# Target to build complete boot image for OpenSBI
.PHONY: boot-image
boot-image: $(FINAL_BOOT_HEX)
	@echo "=== Boot image ready ==="
	@echo "Location: $(FINAL_BOOT_HEX)"
	@echo "Size: $$(du -h $(FINAL_BOOT_HEX) | cut -f1)"
	@ls -lh $(FINAL_BOOT_HEX)

# Build fw_jump OpenSBI firmware
$(OPENSBI_FW_JUMP_ELF):
	@echo "=== Building OpenSBI fw_jump (bootble platform, no embedded FDT) ==="
	$(MAKE) -C $(OPENSBI_DIR) PLATFORM=bootble \
		CROSS_COMPILE=riscv64-linux-gnu- \
		PLATFORM_RISCV_XLEN=32 \
		PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei \
		PLATFORM_RISCV_ABI=ilp32 \
		FW_TEXT_START=0x00000000 \
		FW_JUMP_ADDR=0x00800000 \
		FW_JUMP_FDT_ADDR=0x003F0000
	@echo "=== OpenSBI build complete (bootble platform with full FDT support) ==="

# Convert OpenSBI fw_jump to hex
$(OPENSBI_JUMP_HEX): $(OPENSBI_FW_JUMP_ELF) | $(BUILD_DIR)
	@echo "Converting fw_jump to hex..."
	$(RISCV_OBJCOPY) -O binary $< $(OPENSBI_JUMP_BIN)
	od -An -tx4 -w4 -v $(OPENSBI_JUMP_BIN) | awk '{print $$1}' > $@
	@echo "OpenSBI hex: $(OPENSBI_JUMP_HEX) ($$(wc -l < $@) words)"

# Convert DTB to hex (use od to get correct word endianness like OpenSBI)
$(DTB_HEX): $(DTB_SOURCE) | $(BUILD_DIR)
	@echo "Converting DTB to hex..."
	od -An -tx4 -w4 -v $(DTB_SOURCE) | awk '{print $$1}' > $@
	@echo "DTB hex: $(DTB_HEX) ($$(wc -l < $@) words)"

# Build boot stub
$(BOOT_STUB_HEX): $(TEST_DIR)/boot_opensbi.S | $(BUILD_DIR)
	@echo "Building boot stub..."
	$(RISCV_CC) -x assembler-with-cpp $(RISCV_CFLAGS) $(RISCV_LDFLAGS) -o $(BUILD_DIR)/boot_opensbi.elf $<
	$(RISCV_OBJCOPY) -O binary --remove-section=.note.gnu.build-id $(BUILD_DIR)/boot_opensbi.elf $(BUILD_DIR)/boot_opensbi.bin
	od -An -tx4 -w4 -v $(BUILD_DIR)/boot_opensbi.bin | awk '{print $$1}' > $@
	@echo "Boot stub hex: $(BOOT_STUB_HEX) ($$(wc -l < $@) words)"

# Create final boot image
$(FINAL_BOOT_HEX): $(BOOT_STUB_HEX) $(OPENSBI_JUMP_HEX) $(DTB_HEX)
	@echo "Creating final boot image..."
	@bash scripts/create_final_boot_image.sh
	@echo "Final boot image created: $(FINAL_BOOT_HEX)"

# Verilator simulation
.PHONY: sim
sim: $(BUILD_DIR) $(WAVE_DIR)
	@# Verify test hex file exists
	@if [ ! -f "$(TEST_HEX)" ]; then \
		echo "ERROR: Test hex file not found: $(TEST_HEX)"; \
		echo "Run 'make TEST=$(TEST) sw' first to build software"; \
		exit 1; \
	fi
	@echo "Building simulator with TEST_PROGRAM=$(TEST_HEX)"
	$(VERILATOR) $(VFLAGS) -DTEST_PROGRAM=\"$(shell pwd)/$(TEST_HEX)\" $(RTL_SOURCES) $(TB_SOURCES) $(shell pwd)/$(CPP_SOURCES)
	@echo "=== Verilator build complete ==="
	@echo "Simulator binary: $(BUILD_DIR)/verilator/Vtb_soc"
	@echo "Boot image: $(TEST_HEX) ($$(du -h $(TEST_HEX) | cut -f1))"

# Build simulator specifically for OpenSBI boot
.PHONY: sim-boot
sim-boot: $(FINAL_BOOT_HEX)
	@echo "Building simulator for OpenSBI boot..."
	$(MAKE) TEST=final_boot HEX_FILE=$(FINAL_BOOT_HEX) sim
	@echo "=== Ready to boot OpenSBI ==="
	@echo "Run: ./$(BUILD_DIR)/verilator/Vtb_soc"

# Run simulation with specific test
.PHONY: run
run: sw sim
	@echo "=== Running simulation with $(TEST) ==="
	./$(BUILD_DIR)/verilator/Vtb_soc

# Run simulation with a specific HEX file
.PHONY: run-hex
run-hex: sim
	@echo "=== Running simulation with HEX_FILE=$(HEX_FILE) ==="
	./$(BUILD_DIR)/verilator/Vtb_soc

# View waveforms
.PHONY: wave
wave:
	gtkwave $(WAVE_DIR)/tb_soc.vcd &

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(WAVE_DIR)/*.vcd
	rm -rf $(WAVE_DIR)/*.fst
	@echo "Clean complete"

# Clean everything including OpenSBI
.PHONY: distclean
distclean: clean
	@echo "Deep cleaning including OpenSBI..."
	$(MAKE) -C $(OPENSBI_DIR) distclean PLATFORM=bootble
	@echo "Distclean complete"

# Rebuild everything from scratch
.PHONY: rebuild
rebuild: clean boot-image sim-boot
	@echo "=== Full rebuild complete ==="
	@echo "Ready to run: ./$(BUILD_DIR)/verilator/Vtb_soc"

# Verify build (check all required files exist)
.PHONY: verify-build
verify-build:
	@echo "=== Verifying build files ==="
	@echo -n "Boot stub hex...        "; test -f $(BOOT_STUB_HEX) && echo "✓" || echo "✗ MISSING"
	@echo -n "OpenSBI fw_jump hex...  "; test -f $(OPENSBI_JUMP_HEX) && echo "✓" || echo "✗ MISSING"
	@echo -n "DTB hex...              "; test -f $(DTB_HEX) && echo "✓" || echo "✗ MISSING"
	@echo -n "Final boot image...     "; test -f $(FINAL_BOOT_HEX) && echo "✓" || echo "✗ MISSING"
	@echo -n "Simulator binary...     "; test -f $(BUILD_DIR)/verilator/Vtb_soc && echo "✓" || echo "✗ MISSING"
	@echo ""
	@if [ -f $(FINAL_BOOT_HEX) ]; then \
		echo "Boot image size: $$(du -h $(FINAL_BOOT_HEX) | cut -f1)"; \
		echo "Boot image lines: $$(wc -l < $(FINAL_BOOT_HEX)) words"; \
	fi
	@echo ""
	@echo "=== Verification complete ==="

# Lint RTL
.PHONY: lint
lint:
	$(VERILATOR) --lint-only $(VFLAGS) $(RTL_SOURCES) $(TB_SOURCES)

# Run all tests
.PHONY: test-all
test-all:
	@echo "=== Running All Tests ==="
	@echo ""
	@for test in test_alu test_memory test_branch test_muldiv; do \
		echo "========================================"; \
		echo "Running $$test..."; \
		echo "========================================"; \
		$(MAKE) clean >/dev/null 2>&1; \
		$(MAKE) TEST=$$test sw sim >/dev/null 2>&1; \
		if $(MAKE) TEST=$$test run | grep -q "ALL TESTS PASSED"; then \
			echo "✓ $$test: PASSED"; \
		else \
			echo "✗ $$test: FAILED"; \
		fi; \
		echo ""; \
	done
	@echo "=== All Tests Complete ==="

# Help
.PHONY: help
help:
	@echo "RISC-V SoC Makefile"
	@echo "==================="
	@echo ""
	@echo "Quick Start:"
	@echo "  make rebuild       - Clean and rebuild everything (OpenSBI + simulator)"
	@echo "  ./build/verilator/Vtb_soc - Run the simulation"
	@echo ""
	@echo "Main Targets:"
	@echo "  boot-image         - Build OpenSBI boot image (boot stub + fw_jump + DTB)"
	@echo "  sim-boot           - Build simulator configured for OpenSBI boot"
	@echo "  rebuild            - Clean and rebuild everything from scratch"
	@echo "  verify-build       - Verify all required files are present"
	@echo ""
	@echo "Development Targets:"
	@echo "  sim                - Build Verilator simulation with TEST hex file"
	@echo "  sw                 - Build software test program"
	@echo "  run                - Build software and run simulation"
	@echo "  test-all           - Run all test programs automatically"
	@echo ""
	@echo "Utility Targets:"
	@echo "  wave               - View waveforms in GTKWave"
	@echo "  lint               - Lint RTL with Verilator"
	@echo "  clean              - Clean build artifacts (keep OpenSBI)"
	@echo "  distclean          - Clean everything including OpenSBI"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  TEST               - Specify test program (default: hello)"
	@echo "                       Example: make TEST=test_alu run"
	@echo ""
	@echo "Build Components:"
	@echo "  Boot stub:         sw/tests/boot_opensbi.S"
	@echo "  OpenSBI firmware:  opensbi/build/platform/bootble/firmware/fw_jump.elf"
	@echo "  Device tree:       dts/bootble.dtb"
	@echo "  Final boot image:  build/final_boot.hex"
	@echo ""
