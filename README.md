

Bootble RISC-V — RV32IMA Softcore that Boots OpenSBI

🔗 Deep Technical Blog Post:
https://silicogenai.netlify.app/blog/risc-v-soft-processor-core

🎥 Project Demo Video (Click to Watch):



---

A complete RV32IMA processor built from scratch in SystemVerilog, simulated with Verilator.
Primary goal achieved: boots OpenSBI v1.8.1 and prints its full banner.


---

Project Status: COMPLETE ✅

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


---

Prerequisites

Tool	Version	Install

Verilator	5.020+	apt install verilator
RISC-V Toolchain	Any	apt install gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
Device Tree Compiler	Any	apt install device-tree-compiler
GTKWave (optional)	Any	apt install gtkwave


Verify:

verilator --version
riscv64-linux-gnu-gcc --version
dtc --version


---

Quick Start — Boot OpenSBI

# 1. Build the Verilator simulator (boot image already included as build/final_boot.hex)
make sim-boot

# 2. Run — UART output goes to /tmp/uart_output.txt
./scripts/boot_opensbi.sh

This will display the full OpenSBI banner:

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

Note: UART output is written to /tmp/uart_output.txt by the SystemVerilog testbench. The script above displays it cleanly. If you run the simulator directly (./build/verilator/Vtb_soc), check that file for the boot banner.

To verify key boot lines:

cat /tmp/uart_output.txt | grep -E "OpenSBI|Platform Name|Console Device|Firmware Base|Runtime SBI"


---

How It Works

The boot image is a single hex file loaded into RAM at reset:

0x00000000  OpenSBI fw_jump firmware (entry point)
0x00040000  OpenSBI RW data segment
0x003F0000  Device Tree Blob (DTB)
0x00800000  Next-stage target (empty — OpenSBI halts here)
0x02000000  CLINT (timer)
0x10000000  UART 16550

On reset the CPU starts at 0x0, which is the OpenSBI entry point.
OpenSBI reads the DTB, initialises the UART, and prints its banner.
When it tries to jump to 0x800000 it traps (no payload) and loops in M-mode.


---

Rebuilding from Scratch

Rebuild everything

make rebuild
./build/verilator/Vtb_soc

Rebuild OpenSBI only

cd opensbi && make PLATFORM=bootble \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_JUMP_ADDR=0x00800000 \
    FW_JUMP_FDT_ADDR=0x003F0000 \
    PLATFORM_RISCV_XLEN=32 \
    FW_TEXT_START=0x0

Rebuild boot image only

./create_final_boot_image.sh

Rebuild Verilator simulator only

make sim-boot


---

Running Unit Tests

⚠️ Unit tests are different from booting OpenSBI. Unit tests load small test programs, while OpenSBI boot loads the full firmware image.

The processor passes a full suite of RV32IMA unit tests:

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


---

Architecture

CPU Core (rtl/core/cpu_core.sv)

Multi-cycle, non-pipelined, 11-state machine

RESET → FETCH → FETCH_WAIT → DECODE → EXECUTE → MEMORY → MEMORY_WAIT → WRITEBACK → TRAP

AMO path: EXECUTE → MEMORY → MEMORY_WAIT → AMO_WRITE → AMO_WRITE_WAIT → WRITEBACK

Split ibus / dbus

32 general-purpose registers

Full M-mode CSR file (40+ registers)


M Extension (rtl/core/muldiv.sv)

Single-cycle multiply

Iterative divide


Peripherals

uart_16550.sv

ram.sv

timer.sv



---

Project Statistics

Metric	Value

RTL lines	~2,600 SystemVerilog
Bugs fixed	29
Unit tests	200
Test pass rate	100%
Simulation speed	~400K cycles/sec
OpenSBI version booted	v1.8.1



---

What's Next

1. FPGA synthesis


2. Next-stage payload


3. Supervisor mode + MMU


4. Linux boot




---

References

RISC-V ISA Specification

RISC-V Privileged Specification

OpenSBI

Verilator Manual



---

License

Open source educational project.


---

