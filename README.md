# Bootble RISC-V — RV32IMA Softcore that Boots OpenSBI

A complete RV32IMA processor built from scratch in SystemVerilog, simulated with Verilator.  
**Primary goal achieved: boots OpenSBI v1.8.1 and prints its full banner.**

## Project Status: COMPLETE ✅

```
OpenSBI v1.8.1-32-g8d1c21b3
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : Bootble RV32IMA
Platform Console Device     : uart8250
Firmware Base               : 0x0
Firmware RW Offset          : 0x40000
Domain0 Next Address        : 0x00800000
Boot HART Base ISA          : rv32ima
Runtime SBI Version         : 3.0
```

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Verilator | 5.020+ | `apt install verilator` |
| RISC-V Toolchain | Any | `apt install gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu` |
| Device Tree Compiler | Any | `apt install device-tree-compiler` |
| GTKWave (optional) | Any | `apt install gtkwave` |

Verify:
```bash
verilator --version
riscv64-linux-gnu-gcc --version
dtc --version
```

## Quick Start — Boot OpenSBI

```bash
# 1. Build the Verilator simulator (boot image already included as build/final_boot.hex)
make sim-boot

# 2. Run — UART output prints directly to your terminal
./build/verilator/Vtb_soc
```

You should see the full OpenSBI banner printed to your terminal:

```
OpenSBI v1.8.1-32-g8d1c21b3
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : Bootble RV32IMA
Platform Features           : medeleg
Platform HART Count         : 1
Platform Console Device     : uart8250
Firmware Base               : 0x0
Firmware Size               : 308 KB
Firmware RW Offset          : 0x40000
Domain0 Next Address        : 0x00800000
Boot HART Base ISA          : rv32ima
Runtime SBI Version         : 3.0
```

To verify all expected lines are present:

```bash
./build/verilator/Vtb_soc | grep -E \
  "OpenSBI|Platform Name|Platform HART Count|Platform Console|Firmware Base|Firmware RW Offset|Domain0 Next|Boot HART|Runtime SBI"
```

All 9 lines should appear. If any are missing, something is wrong with the boot.

## How It Works

The boot image is a single hex file loaded into RAM at reset:

```
0x00000000  OpenSBI fw_jump firmware (entry point)
0x00040000  OpenSBI RW data segment
0x003F0000  Device Tree Blob (DTB)
0x00800000  Next-stage target (empty — OpenSBI halts here)
0x02000000  CLINT (timer)
0x10000000  UART 16550
```

On reset the CPU starts at `0x0`, which is the OpenSBI entry point.  
OpenSBI reads the DTB, initialises the UART, and prints its banner.  
When it tries to jump to `0x800000` it traps (no payload) and loops in M-mode.

## Rebuilding from Scratch

### Rebuild everything
```bash
make rebuild
./build/verilator/Vtb_soc
```

### Rebuild OpenSBI only
```bash
cd opensbi && make PLATFORM=bootble \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_JUMP_ADDR=0x00800000 \
    FW_JUMP_FDT_ADDR=0x003F0000 \
    PLATFORM_RISCV_XLEN=32 \
    FW_TEXT_START=0x0
```

### Rebuild boot image only
```bash
./create_final_boot_image.sh
```

### Rebuild Verilator simulator only
```bash
make sim-boot
```

## Running Unit Tests

**⚠️ Important:** Unit tests are **different** from booting OpenSBI. Unit tests load small test programs, while OpenSBI boot loads the full firmware image.

The processor passes a full suite of RV32IMA unit tests:

```bash
# Single test
make TEST=test_trap sw sim && ./build/verilator/Vtb_soc

# All unit tests
for t in test_alu test_memory test_branch test_muldiv test_trap \
          test_illegal_simple test_misalign_simple \
          test_timer_irq test_sw_irq test_firmware; do
    echo -n "$t: "
    make TEST=$t sw sim >/dev/null 2>&1
    timeout 30 ./build/verilator/Vtb_soc 2>&1 | grep -E "PASS|FAIL|OK|FIRMWARE"
done
```

**Note:** If you see "64 TESTS FAILED" with instructions in memory, you likely ran `make TEST=something` which loads a test program instead of OpenSBI. To boot OpenSBI, use `make sim-boot` instead (see "Quick Start" section above).

| Test | What it verifies | Expected output |
|------|-----------------|-----------------|
| `test_alu` | All RV32I ALU ops | `PASS` |
| `test_memory` | Loads, stores, byte/halfword | `PASS` |
| `test_branch` | All branch instructions | `PASS` |
| `test_muldiv` | M-extension mul/div/rem | `PASS` |
| `test_trap` | ECALL / EBREAK / MRET | `OK` |
| `test_illegal_simple` | Illegal instruction exception | `2P` |
| `test_misalign_simple` | Load misalignment | `4P` |
| `test_timer_irq` | Timer interrupt | `I7P` |
| `test_sw_irq` | Software interrupt | `I3P` |
| `test_firmware` | Full firmware boot sequence | `FIRMWARE_OK` |

## Architecture

**CPU Core** (`rtl/core/cpu_core.sv`)
- Multi-cycle, non-pipelined, 11-state machine
- RESET → FETCH → FETCH_WAIT → DECODE → EXECUTE → MEMORY → MEMORY_WAIT → WRITEBACK → TRAP
- AMO path: EXECUTE → MEMORY → MEMORY_WAIT → AMO_WRITE → AMO_WRITE_WAIT → WRITEBACK
- Split ibus (instruction fetch, PC-driven) / dbus (data access, ALU-driven)
- 32 general-purpose registers
- Full M-mode CSR file (40+ registers, including S-mode read-zero/write-ignore stubs)

**M Extension** (`rtl/core/muldiv.sv`)
- Single-cycle multiply, iterative divide
- Handles signed/unsigned variants and remainder

**Peripherals**
- `rtl/peripherals/uart_16550.sv` — ns16550a compatible, `reg_shift=2` word addressing
- `rtl/peripherals/ram.sv` — 4 MB, initialised from hex file
- `rtl/peripherals/timer.sv` — CLINT-compatible mtime/mtimecmp

**OpenSBI Platform** (`opensbi/platform/bootble/`)
- Custom platform with `nascent_init` initialising uart8250
- `platform_ops_addr` patched at runtime in `fw_platform_init`

## Debugging

### Waveforms
```bash
./build/verilator/Vtb_soc   # generates sim/waveforms/tb_soc.vcd
gtkwave sim/waveforms/tb_soc.vcd
```

Key signals:
- `tb_soc.dut.u_cpu_core.pc` — program counter
- `tb_soc.dut.u_cpu_core.state` — CPU state machine
- `tb_soc.dut.u_cpu_core.instruction` — current instruction word
- `tb_soc.dut.u_cpu_core.trap_taken` — exception/interrupt events

### Simulation log (cycle probes and platform init milestones)
```bash
./build/verilator/Vtb_soc 2>&1 | grep PROBE
```

## Project Statistics

| Metric | Value |
|--------|-------|
| RTL lines | ~2,600 SystemVerilog |
| Bugs fixed | 29 critical bugs |
| Unit tests | 200 (187 ISA + 13 exception/interrupt) |
| Test pass rate | 100% |
| Simulation speed | ~400 K cycles/second |
| OpenSBI version booted | v1.8.1 |

## Documentation

| File | Contents |
|------|----------|
| `.silicogen_process_documenation/BLOG_POST.md` | Full technical journey |
| `.silicogen_process_documenation/BUG_LOG.md` | All 29 bugs with root cause and fix |
| `.silicogen_process_documenation/TODO.md` | Phase-by-phase progress |
| `docs/` | Microarchitecture specs (datapath, CSRs, memory map) |

## What's Next (Phase 8)

The simulation is complete. Potential extensions:

1. **FPGA synthesis** — target Xilinx Artix-7 (Arty A7) or Intel Cyclone V (DE10-Nano)
2. **Next-stage payload** — add a minimal S-mode stub at `0x800000` so OpenSBI hands off cleanly
3. **Supervisor mode + MMU** — the prerequisite for booting Linux
4. **Linux boot** — the ultimate goal

## References

- [RISC-V ISA Specification](https://riscv.org/specifications/)
- [RISC-V Privileged Specification](https://riscv.org/specifications/privileged-isa/)
- [OpenSBI](https://github.com/riscv-software-src/opensbi)
- [Verilator Manual](https://verilator.org/guide/latest/)
- [AI creates a bootable VM — Uros Popovic](https://popovicu.com/posts/ai-creates-bootable-vm/)
- [RISC-V SBI and the full boot process](https://popovicu.com/posts/risc-v-sbi-and-full-boot-process/)

## License

Open source educational project.
