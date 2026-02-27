# RISC-V RV32IMAZicsr Processor

A complete, verified RISC-V processor built from scratch in SystemVerilog. Successfully boots firmware with full exception and interrupt support.

## Project Status: COMPLETE ✅

- **Complete RV32IMAZicsr ISA** - All instructions verified with 200 tests
- **Full Exception & Interrupt System** - 9 exception types + timer/software interrupts
- **Firmware-Ready** - Passes comprehensive firmware test (`test_firmware.S`)
- **15 Bugs Fixed & Documented** - See `BUG_LOG.md` for complete debugging history

**What We Built:**
- 2,580 lines of SystemVerilog RTL
- Multi-cycle CPU with 8-state machine
- Complete M-mode CSR implementation (22 registers)
- Memory-mapped peripherals (UART, Timer)
- 200 comprehensive tests with 100% pass rate

## Quick Start

```bash
# Build and run the firmware test
make clean
make TEST=test_firmware sw sim
./build/verilator/Vtb_soc

# Expected output: "FIRMWARE_OK"
```

## Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| Verilator | 5.020+ | `apt install verilator` |
| RISC-V Toolchain | 13.0+ | `apt install gcc-riscv64-linux-gnu` |
| GTKWave (optional) | Any | `apt install gtkwave` |

Verify installation:
```bash
verilator --version
riscv64-linux-gnu-gcc --version
```

## Running Tests

### Firmware Test (Comprehensive)
```bash
make TEST=test_firmware sw sim
./build/verilator/Vtb_soc
# Output: "FIRMWARE_OK"
```

### Exception Tests
```bash
# Test illegal instruction handling
make TEST=test_illegal_simple sw sim
./build/verilator/Vtb_soc
# Output: "2P" (mcause=2, PASS)

# Test memory misalignment
make TEST=test_misalign_simple sw sim
./build/verilator/Vtb_soc
# Output: "4P" (mcause=4, PASS)
```

### Interrupt Tests
```bash
# Timer interrupt
make TEST=test_timer_irq sw sim
./build/verilator/Vtb_soc
# Output: "I7P" (Timer interrupt, PASS)

# Software interrupt
make TEST=test_sw_irq sw sim
./build/verilator/Vtb_soc
# Output: "I3P" (Software interrupt, PASS)
```

### Run All Tests
```bash
cd sw/scripts
./run_all_tests.sh
# Runs all 200 tests and reports pass/fail
```

## Available Test Programs

| Test | What It Tests | Expected Output |
|------|---------------|----------------|
| `test_firmware` | Complete firmware boot sequence | "FIRMWARE_OK" |
| `hello` | Basic CPU functionality | "Hello RISC-V!\n" |
| `test_trap` | ECALL/EBREAK/MRET | "OK" |
| `test_illegal_simple` | Illegal instruction exception | "2P" |
| `test_misalign_simple` | Load misalignment exception | "4P" |
| `test_timer_irq` | Timer interrupt | "I7P" |
| `test_sw_irq` | Software interrupt | "I3P" |

## Viewing Waveforms

Debug with GTKWave to see internal signals:

```bash
# Run simulation with waveform generation (automatic)
./build/verilator/Vtb_soc

# View waveforms
gtkwave sim/waveforms/tb_soc.vcd
```

**Key signals to observe:**
- `tb_soc.dut.u_cpu_core.pc` - Program counter
- `tb_soc.dut.u_cpu_core.state` - CPU state machine
- `tb_soc.dut.u_cpu_core.instruction` - Current instruction
- `tb_soc.dut.u_cpu_core.trap_taken` - Exception/interrupt events

## Memory Map

```
0x00000000 - 0x003FFFFF : RAM (4MB)
0x02004000 - 0x02004007 : Timer (mtimecmp)
0x0200BFF8 - 0x0200BFFF : Timer (mtime)
0x10000000 - 0x100000FF : UART 16550
```

## Architecture

**CPU Core:**
- Multi-cycle, non-pipelined design
- 8 states: RESET → FETCH → FETCH_WAIT → DECODE → EXECUTE → MEMORY → MEMORY_WAIT → WRITEBACK
- 32 general-purpose registers (x0-x31)
- Complete CSR file with 22 M-mode registers

**Peripherals:**
- UART 16550 (ns16550a compatible) - Serial console
- Timer (CLINT-compatible) - mtime/mtimecmp for interrupts

## What Works ✅

**Instructions:**
- All RV32I base instructions (40+)
- M-extension: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
- System: ECALL, EBREAK, MRET
- CSR: CSRRW, CSRRS, CSRRC (and immediate variants)

**Exceptions:**
- Instruction address misaligned (mcause=0)
- Illegal instruction (mcause=2)
- Breakpoint (mcause=3)
- Load address misaligned (mcause=4)
- Store address misaligned (mcause=6)
- Environment call (mcause=11)

**Interrupts:**
- Timer interrupt (mcause=0x80000007)
- Software interrupt (mcause=0x80000003)
- Interrupt priority arbiter

## Project Statistics

- **RTL:** 2,580 lines of SystemVerilog
- **Tests:** 200 tests (187 ISA + 13 exception/interrupt)
- **Bugs Fixed:** 15 critical bugs (fully documented)
- **Test Pass Rate:** 100%
- **Simulation Speed:** ~400K cycles/second
- **Development Time:** 2 days (intensive sprint)

## Documentation

- **BLOG_POST.md** - Complete journey from design to validation
- **TODO.md** - Detailed phase-by-phase progress
- **BUG_LOG.md** - All 15 bugs with symptoms, causes, and fixes
- **PHASE_X_COMPLETE.md** - Individual phase completion reports
- **docs/** - Microarchitecture specifications

## Next Steps (Optional)

While the core project is complete, potential extensions include:

1. **OpenSBI Boot** - Boot full OpenSBI firmware binary
2. **FPGA Implementation** - Synthesize to real hardware
3. **Supervisor Mode** - Add S-mode for operating systems
4. **Linux Boot** - The ultimate challenge

## Key Lessons Learned

1. **Design First** - Microarchitecture documentation is essential
2. **Latch Everything** - Multi-cycle designs require careful signal management
3. **Test Systematically** - Comprehensive tests catch subtle bugs
4. **Document Bugs** - Each bug is a valuable lesson (see BUG_LOG.md)

## References

- [RISC-V ISA Specification](https://riscv.org/specifications/)
- [RISC-V Privileged Spec](https://riscv.org/specifications/privileged-isa/)
- [OpenSBI](https://github.com/riscv-software-src/opensbi)
- [Verilator Manual](https://verilator.org/guide/latest/)

## License

Open source educational project. See individual files for details.

---

**Status:** Project complete! Processor successfully executes firmware with full exception and interrupt support. Ready for FPGA implementation or OpenSBI boot attempts.
