# How to Resume This Project

**Quick Start Guide for New Sessions**

## Current State: PHASE 7 COMPLETE

OpenSBI v1.8.1 boots and prints its full banner on our RV32IMA softcore.  
The primary project goal has been achieved.

---

## Step 1: Read These Files (In Order)
1. `TODO.md` — Current phase status and bug list
2. `BUG_LOG.md` — All 29 bugs and fixes in detail
3. `README.md` — User documentation

## Step 2: Verify Environment
```bash
verilator --version        # Should be v5.020+
riscv64-linux-gnu-gcc --version
make --version
```

## Step 3: Run the Boot Simulation
```bash
# Boot OpenSBI (the project goal!)
make TEST=final_boot HEX_FILE=build/final_boot.hex sim
rm -f /tmp/uart_output.txt
./build/verilator/Vtb_soc > /tmp/sim.log 2>&1
cat /tmp/uart_output.txt
```

Expected output:
```
OpenSBI v1.8.1-32-g8d1c21b3
   ____                    _____ ____ _____
  ...
Platform Name               : Bootble RV32IMA
Platform Console Device     : uart8250
Firmware Base               : 0x0
Boot HART Base ISA          : rv32ima
```

---

## Memory Map

| Address      | Contents                                     |
|--------------|----------------------------------------------|
| `0x00000000` | OpenSBI fw_jump firmware entry               |
| `0x00040000` | OpenSBI RW data (`fw_rw_offset = 0x40000`)   |
| `0x003F0000` | DTB (`FW_JUMP_FDT_ADDR`)                     |
| `0x00800000` | Next-stage target (empty — OpenSBI traps here) |
| `0x02000000` | CLINT (timer)                                |
| `0x10000000` | UART 16550                                   |

---

## Key Files

| File | Description |
|------|-------------|
| `rtl/core/cpu_core.sv` | Main CPU state machine (RV32IMA) |
| `rtl/core/muldiv.sv` | Multiply/divide unit |
| `rtl/peripherals/uart_16550.sv` | UART — uses `addr[4:2]` for reg_shift=2 |
| `rtl/soc/riscv_soc.sv` | Top-level SoC |
| `sim/testbenches/tb_soc.sv` | Verilator testbench |
| `opensbi/platform/bootble/platform.c` | Custom OpenSBI platform |
| `opensbi/firmware/fw_base.S` | Modified: `li a4, FW_TEXT_START` for fw_start |
| `opensbi/firmware/fw_jump.S` | Modified: `li a0, 0` for coldboot path |
| `bootble.dts` | Device tree: `reg-shift=2`, `reg-io-width=4` |
| `Makefile` | `FW_JUMP_ADDR=0x00800000`, `PLATFORM_RISCV_XLEN=32` |
| `create_final_boot_image.sh` | Builds final boot hex (OpenSBI + DTB) |

---

## Build Commands

```bash
# Full rebuild from scratch
make TEST=final_boot HEX_FILE=build/final_boot.hex sim

# Rebuild OpenSBI only
cd opensbi && make PLATFORM=bootble \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_JUMP_ADDR=0x00800000 \
    FW_JUMP_FDT_ADDR=0x003F0000 \
    PLATFORM_RISCV_XLEN=32 \
    FW_TEXT_START=0x0

# Rebuild boot image only
./create_final_boot_image.sh

# Run ISA regression tests
for test in test_alu test_memory test_branch test_muldiv test_trap; do
    make TEST=$test sw sim >/dev/null 2>&1
    timeout 30 ./build/verilator/Vtb_soc 2>&1 | tail -5
done
```

---

## What Was Fixed (Summary of All 29 Bugs)

### Phase 4–6D (Bugs #1–#19): CPU core, exceptions, interrupts
All standard CPU bugs: signal latching, PC update, trap flow, divide unit.  
See BUG_LOG.md for details.

### Phase 7 — OpenSBI integration (Bugs #20–#29)

| # | Fix | File |
|---|-----|------|
| #20 | DTB endianness: `xxd` → `od -tx4` | `Makefile` |
| #21 | Warmboot path: `li a0,0` in fw_jump | `fw_jump.S` |
| #22 | RV64 on RV32: add `PLATFORM_RISCV_XLEN=32` | Build flags |
| #23 | `nascent_init` not populated | `platform.c` |
| #24 | Halfword store `wstrb` wrong mask | `cpu_core.sv` |
| #25 | Byte store data not replicated | `cpu_core.sv` |
| #26 | `platform_ops_addr` = NULL | `platform.c` |
| #27 | `fw_rw_offset` not power-of-2 | `fw_base.S` |
| #28 | `FW_JUMP_ADDR=0x0` rejected | `Makefile` |
| #29 | UART `addr[2:0]` → `addr[4:2]` for reg_shift=2 | `uart_16550.sv` |

---

## Next Phase: Phase 8 — FPGA Implementation

The simulation is complete. The next goal is to synthesise the design for an FPGA.

Suggested targets:
- Xilinx Artix-7 (Arty A7-35T/100T)
- Intel Cyclone V (DE10-Nano)

Key tasks:
- Add FPGA constraints (timing, pin assignments)
- Replace `$readmemh` RAM init with block RAM IP
- Add physical UART TX pin mapping
- Verify timing closure at target frequency

---

**Last Updated:** 2026-02-27  
**Phase:** 7 COMPLETE — OpenSBI boots  
**Bugs Fixed:** 29 total  
**Resume Time:** < 2 minutes — just run `cat /tmp/uart_output.txt` after `./build/verilator/Vtb_soc`
