# How to Resume This Project

**Quick Start Guide for New Sessions**

## Step 1: Read These Files (In Order)
1. `TODO.md` - See what needs to be done next
2. `.context` - Full project context and state
3. `README.md` - User documentation
4. `BLOG_POST.md` - Detailed technical journey

## Step 2: Verify Environment
```bash
# Check tools installed
verilator --version        # Should be v5.020+
riscv64-linux-gnu-gcc --version
make --version

# Check git status
git status
git log --oneline -5
```

## Step 3: Build & Test
```bash
# Clean everything
make clean

# Build software and hardware
make sw && make sim

# Run simulation (should print "Hello RISC-V!")
./build/verilator/Vtb_soc
```

## Step 4: Start Working
- **Phase 5 (Current):** M-extension verification and A-extension implementation
- See `TODO.md` for detailed task list
- See `.context` for complete project understanding

## Quick Reference

### Build Commands
```bash
make clean    # Remove all build artifacts
make sw       # Build test program
make sim      # Build Verilator simulation
make          # Build both sw and sim
```

### Run Simulation
```bash
./build/verilator/Vtb_soc
```

### View Waveforms
```bash
gtkwave sim/waveforms/tb_soc.vcd
```

### Check Disassembly
```bash
cat build/hello.dump
```

## Current Status: Phase 4 Complete
- Processor executes "Hello RISC-V!" successfully
- All 8 hardware bugs fixed
- Ready to start Phase 5 (M/A extension testing)

## Git Repository
- **Remote:** https://github.com/Silicogen-Labs/silicogen-proj-bootable-riscv-opensbi.git
- **Branch:** main
- **Status:** Clean, all build artifacts in .gitignore

## Important Files
- `rtl/core/cpu_core.sv` - Main CPU (637 lines)
- `sim/testbenches/tb_soc.sv` - Testbench
- `sw/tests/hello.S` - Test program
- `Makefile` - Build system

## If Something Breaks
1. Check `TODO.md` for known issues
2. Check `.context` for debugging techniques
3. Look at waveforms with GTKWave
4. Compare with disassembly (`build/hello.dump`)

---

**Last Updated:** 2026-02-26  
**Session Duration:** You should be able to resume in < 5 minutes with these files
