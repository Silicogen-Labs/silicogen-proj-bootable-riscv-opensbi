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
TEST_PROGRAM = $(TEST_DIR)/$(TEST).S
TEST_ELF = $(BUILD_DIR)/$(TEST).elf
TEST_BIN = $(BUILD_DIR)/$(TEST).bin
TEST_HEX = $(BUILD_DIR)/$(TEST).hex
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
	$(RISCV_OBJCOPY) -O binary $< $@

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

# Verilator simulation
.PHONY: sim
sim: $(BUILD_DIR) $(WAVE_DIR)
	$(VERILATOR) $(VFLAGS) -DTEST_PROGRAM=\"$(TEST_HEX)\" $(RTL_SOURCES) $(TB_SOURCES) $(shell pwd)/$(CPP_SOURCES)
	@echo "=== Verilator build complete ==="

# Run simulation with specific test
.PHONY: run
run: sw sim
	@echo "=== Running simulation with $(TEST) ==="
	./$(BUILD_DIR)/verilator/Vtb_soc

# View waveforms
.PHONY: wave
wave:
	gtkwave $(WAVE_DIR)/tb_soc.vcd &

# Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(WAVE_DIR)/*.vcd
	rm -rf $(WAVE_DIR)/*.fst

# Clean everything including generated files
.PHONY: distclean
distclean: clean
	rm -rf $(BUILD_DIR)
	rm -rf $(WAVE_DIR)

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
	@echo "Targets:"
	@echo "  all        - Build and run simulation (default)"
	@echo "  sim        - Compile Verilator simulation"
	@echo "  sw         - Build software test program"
	@echo "  run        - Build software and run simulation"
	@echo "  test-all   - Run all test programs automatically"
	@echo "  wave       - View waveforms in GTKWave"
	@echo "  lint       - Lint RTL with Verilator"
	@echo "  clean      - Clean build artifacts"
	@echo "  distclean  - Clean everything"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  TEST       - Specify test program (default: hello)"
	@echo "               Example: make TEST=test_alu run"
