# UART Output Guide — How to See OpenSBI Boot Banner

## TL;DR — Quick Commands

```bash
# Recommended: Use the boot script (displays UART output cleanly)
./scripts/boot_opensbi.sh

# Alternative: Run simulator directly, then check UART file
./build/verilator/Vtb_soc
cat /tmp/uart_output.txt
```

---

## The Problem: Where Did the UART Output Go?

### What You Might Have Seen

If you ran the simulator directly, you probably saw debug output like this:

```
Cycles: 450k, PC: 0x890, Test[0]: 0x30559073
...
=== Checking Test Results ===
*** 64 TESTS FAILED ***
```

This is **NOT** an error. It just means you're seeing **unit test** output, not the OpenSBI boot banner.

---

## How UART Works in This Simulator

### Architecture Overview

```
┌──────────────────────────┐
│   RTL (uart_16550.sv)    │  ← Hardware UART transmitting serial bits
│   Sends: uart_tx signal  │
└──────────────┬───────────┘
               │ (serial bit stream)
               ↓
┌──────────────────────────┐
│ SystemVerilog Testbench  │  ← Decodes UART bits into ASCII characters
│    (tb_soc.sv lines      │
│     29-75: UART monitor) │
└──────────────┬───────────┘
               │ ($write() calls)
               ↓
     ┌─────────────────────┐
     │ /tmp/uart_output.txt │  ← UART text output file
     └─────────────────────┘
               │
               ↓
     ┌─────────────────────┐
     │ Your terminal (via   │  ← Display with boot script
     │ boot_opensbi.sh)     │
     └─────────────────────┘
```

### Why Not `stdout`?

The **SystemVerilog testbench** (not the C++ simulator) handles UART decoding:

- **`rtl/peripherals/uart_16550.sv`** — Hardware UART that transmits serial bits
- **`sim/testbenches/tb_soc.sv`** — SystemVerilog logic that:
  1. Monitors the `uart_tx` signal (lines 29-75)
  2. Decodes the serial bit stream into ASCII characters
  3. Writes characters using `$write()` (line 68)
  4. Saves to `/tmp/uart_output.txt` (line 863)

The C++ simulator (`sim/sim_main.cpp`) doesn't process UART output — that's handled entirely in SystemVerilog.

---

## How to View OpenSBI Output

### Method 1: Use the Boot Script (Recommended)

```bash
./scripts/boot_opensbi.sh
```

**What it does:**
1. Cleans old log files
2. Runs the simulator with 60-second timeout
3. Displays `/tmp/uart_output.txt` cleanly
4. Shows character count

**Expected output:**

```
=== Bootble RISC-V Soft Processor Core - OpenSBI Boot ===

Starting simulation (60 second timeout)...

=== UART Console Output ===

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
...
Boot HART Base ISA          : rv32ima
...

=== Boot Complete ===
Total characters output: 2351
```

---

### Method 2: Run Simulator Directly

```bash
# Build the simulator (if not already built)
make sim-boot

# Run (will timeout after 60 seconds)
./build/verilator/Vtb_soc

# After it finishes, check UART output
cat /tmp/uart_output.txt
```

---

### Method 3: Real-Time Monitoring (Advanced)

```bash
# Terminal 1: Start simulator
./build/verilator/Vtb_soc

# Terminal 2: Watch UART output in real-time
tail -f /tmp/uart_output.txt
```

---

## Verifying Successful Boot

### Quick Check

```bash
cat /tmp/uart_output.txt | grep -E "OpenSBI|Platform Name|Console Device|Runtime SBI"
```

**Expected output:**

```
OpenSBI v1.8.1-32-g8d1c21b3
Platform Name               : Bootble RV32IMA
Platform Console Device     : uart8250
Runtime SBI Version         : 3.0
```

### Full Banner Check

The complete boot banner should contain:

- **ASCII art logo** (8 lines)
- **Platform info** (13 lines: Name, Features, HART Count, Devices, etc.)
- **Firmware layout** (7 lines: Base, Size, Offsets, Heap, Scratch)
- **SBI version** (2 lines: Runtime version, Extensions)
- **Domain configuration** (12 lines: Name, Boot HART, Regions, Next Address, etc.)
- **Boot HART details** (12 lines: ID, Priv Version, ISA, PMP, etc.)

**Total:** ~2,351 characters

---

## Troubleshooting

### Problem: "64 TESTS FAILED"

**Symptom:**

```
Cycles: 450k, PC: 0x890, Test[0]: 0x30559073
=== Checking Test Results ===
*** 64 TESTS FAILED ***
```

**Cause:** You're running a **unit test program**, not OpenSBI.

**Solution:**

```bash
# If you ran something like:
make TEST=test_alu sw sim  # ← This loads a test program

# Instead, run:
make sim-boot  # ← This loads OpenSBI
./scripts/boot_opensbi.sh
```

---

### Problem: No `/tmp/uart_output.txt` File

**Possible causes:**

1. **Simulator didn't run long enough**
   - OpenSBI takes ~30-50 seconds to boot in simulation
   - The boot script uses a 60-second timeout

2. **Simulator crashed before UART init**
   - Check `/tmp/sim_stderr.log` for errors

**Debug steps:**

```bash
# Check if simulator is still running
ps aux | grep Vtb_soc

# Check simulator logs
ls -lh /tmp/uart_output.txt /tmp/sim_*.log

# Run with verbose output
./build/verilator/Vtb_soc 2>&1 | tee /tmp/full_output.log
```

---

### Problem: Garbled UART Output

**Symptom:** `/tmp/uart_output.txt` has random characters or binary data.

**Cause:** UART baud rate mismatch or timing issue.

**Check:**

```bash
# Verify UART configuration in testbench
grep "UART_CLKS_PER_BIT" sim/testbenches/tb_soc.sv
# Should show: localparam UART_CLKS_PER_BIT = 434;

# Verify UART divisor in RTL
grep "dll <= 8'h" rtl/peripherals/uart_16550.sv
# Should show: dll <= 8'h01;  // Default divisor
```

---

## Additional UART Debug Files

The testbench writes several debug files to `/tmp/`:

| File | Contents |
|------|----------|
| `/tmp/uart_output.txt` | **Main UART output** (OpenSBI banner) |
| `/tmp/uart_debug.txt` | Raw UART write transactions (PC, addr, data) |
| `/tmp/console_tbuf_writes.txt` | Writes to console buffer memory region |
| `/tmp/sim_stdout.log` | Simulator stdout (initial memory dump, probes) |
| `/tmp/sim_stderr.log` | Simulator stderr (C++ debug messages) |

---

## Understanding Debug Output

When you run `./build/verilator/Vtb_soc` directly, you'll see:

```
=== Starting RISC-V SoC Verilator Simulation ===
Reset released at time 200 ns
=== Starting RISC-V SoC Simulation ===
Testbench initialized, clock driven from C++
--- Initial Memory Content (First 16 Words) ---
MEM[0x0] = 0x4a7793
...
Cycles: 50k, PC: 0x1000, Test[0]: 0x0
Cycles: 100k, PC: 0x6d80, Test[0]: 0x0
...
```

**This is normal.** The UART output goes to `/tmp/uart_output.txt`, not the console.

---

## Summary

| What You Want | Command |
|---------------|---------|
| **See OpenSBI banner** | `./scripts/boot_opensbi.sh` |
| **Check if boot succeeded** | `grep "OpenSBI" /tmp/uart_output.txt` |
| **Run simulator manually** | `./build/verilator/Vtb_soc` then `cat /tmp/uart_output.txt` |
| **Debug UART issues** | Check `/tmp/uart_debug.txt` and `/tmp/sim_stderr.log` |

---

## Why This Design?

**Q: Why not output UART text to stdout directly?**

**A:** The UART is decoded in the **SystemVerilog testbench**, not the C++ simulator. SystemVerilog `$write()` calls go to the Verilator log system, which we redirect to files. This approach:

1. **Keeps the RTL pure** — `uart_16550.sv` is just hardware, no simulation hacks
2. **Allows debugging** — UART transactions are logged with PC and timestamps
3. **Matches real hardware** — The UART transmits actual serial bits at baud rate
4. **Separates concerns** — C++ handles clock/reset, SystemVerilog handles protocol decoding

For a production design, you'd connect the `uart_tx` pin to a physical serial port or USB-UART bridge.
