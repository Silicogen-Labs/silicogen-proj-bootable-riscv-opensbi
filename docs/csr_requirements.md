# CSR (Control and Status Register) Requirements

## Overview

This document specifies the Control and Status Registers (CSRs) required for OpenSBI to boot successfully. These registers are part of the Zicsr extension and provide system-level control and status information.

## CSR Addressing

CSRs are accessed using a 12-bit address space (0x000 - 0xFFF). The address format indicates:
- **Bits [11:10]**: Privilege level (00=User, 01=Supervisor, 10=Reserved, 11=Machine)
- **Bits [9:8]**: Read/Write access (00=RW, 01=RW, 10=RW, 11=Read-only)
- **Bits [7:0]**: Register number within privilege level

## Required CSRs for OpenSBI Boot

### Machine Information Registers (Read-Only)

#### 1. `misa` (Machine ISA Register)
- **Address**: 0x301
- **Access**: Read-only (WARL - Write Any, Read Legal)
- **Width**: 32 bits (for RV32)
- **Function**: Describes the ISA implemented by the hart
- **Reset Value**: 0x40141101

**Bit Layout**:
```
[31:30] MXL    = 01 (XLEN=32 for RV32)
[29:26] <reserved> = 0
[25:0]  Extensions = bit vector of supported extensions
```

**Extension Bits** (for RV32IMAZicsr):
- Bit 0 (A): Atomic extension = 1
- Bit 8 (I): Base integer ISA = 1
- Bit 12 (M): Integer multiply/divide = 1
- Bits 1-7, 9-11, 13-25: 0 (other extensions not supported)

**Encoding**: 0x40141101
```
[31:30] = 01 (RV32)
[25:0]  = 0x141101 (A=1, I=1, M=1, others=0)
  Bit 0 (A) = 1
  Bit 8 (I) = 1
  Bit 12 (M) = 1
```

---

#### 2. `mvendorid` (Machine Vendor ID) - Optional
- **Address**: 0xF11
- **Access**: Read-only
- **Function**: Identifies the vendor
- **Reset Value**: 0x00000000 (non-commercial implementation)

---

#### 3. `marchid` (Machine Architecture ID) - Optional
- **Address**: 0xF12
- **Access**: Read-only
- **Function**: Identifies the microarchitecture
- **Reset Value**: 0x00000000 (non-commercial implementation)

---

#### 4. `mimpid` (Machine Implementation ID) - Optional
- **Address**: 0xF13
- **Access**: Read-only
- **Function**: Identifies the implementation version
- **Reset Value**: 0x00000000 (non-commercial implementation)

---

#### 5. `mhartid` (Hart ID Register)
- **Address**: 0xF14
- **Access**: Read-only
- **Function**: Unique hardware thread ID (for multi-core systems)
- **Reset Value**: 0x00000000 (single hart system)
- **Critical**: OpenSBI uses this to identify the boot hart

---

### Machine Trap Setup

#### 6. `mstatus` (Machine Status Register)
- **Address**: 0x300
- **Access**: Read-write
- **Function**: Tracks and controls hart's operating state
- **Reset Value**: 0x00001800 (MPP=11, other fields=0)

**Key Bit Fields** (RV32):
```
[31]    SD       = (FS==11) OR (XS==11) (read-only)
[30:23] <reserved> = 0
[22:17] <reserved> = 0
[16:15] XS[1:0]  = 0 (extension state: off)
[14:13] FS[1:0]  = 0 (floating-point state: off)
[12:11] MPP[1:0] = 11 (previous privilege mode = Machine)
[10:9]  <reserved> = 0
[8]     SPP      = 0 (previous privilege = User, if S-mode implemented)
[7]     MPIE     = 0 (previous MIE value before trap)
[6]     <reserved> = 0
[5]     SPIE     = 0 (previous SIE value, if S-mode implemented)
[4]     UPIE     = 0 (previous UIE value, if N-ext implemented)
[3]     MIE      = 0 (machine interrupt enable)
[2]     <reserved> = 0
[1]     SIE      = 0 (supervisor interrupt enable, if S-mode implemented)
[0]     UIE      = 0 (user interrupt enable, if N-ext implemented)
```

**Critical Fields**:
- **MPP [12:11]**: Machine Previous Privilege - must be set to 11 (M-mode) on reset
- **MIE [3]**: Global machine interrupt enable
- **MPIE [7]**: Previous MIE value before trap

---

#### 7. `mtvec` (Machine Trap Vector Base Address)
- **Address**: 0x305
- **Access**: Read-write
- **Function**: Holds trap vector configuration
- **Reset Value**: 0x00000000 (but should be set by OpenSBI)

**Bit Layout**:
```
[31:2]  BASE[31:2] = Trap vector base address (4-byte aligned)
[1:0]   MODE       = Trap vector mode
                     00 = Direct (all traps jump to BASE)
                     01 = Vectored (async interrupts jump to BASE + 4×cause)
                     10, 11 = Reserved
```

**Implementation Note**: This core **only supports direct mode** (MODE = 00). Writes to MODE bits [1:0] are silently ignored; they are hardwired to 0 in the RTL. Vectored mode is not implemented.

**Usage**: OpenSBI will write this register to set up its trap handler

---

### Machine Trap Handling

#### 8. `mepc` (Machine Exception Program Counter)
- **Address**: 0x341
- **Access**: Read-write
- **Function**: Saves the PC when a trap is taken
- **Reset Value**: 0x00000000

**Details**:
- On trap entry: `mepc ← PC` (address of instruction that caused exception, or next instruction for interrupts)
- On `MRET`: `PC ← mepc`
- Must be 4-byte aligned (lower 2 bits always 0 for RV32I without C-extension)

---

#### 9. `mcause` (Machine Cause Register)
- **Address**: 0x342
- **Access**: Read-write
- **Function**: Indicates the event that caused the trap
- **Reset Value**: 0x00000000

**Bit Layout**:
```
[31]    Interrupt = 1 if trap caused by interrupt, 0 if exception
[30:0]  Exception Code = Specific cause code
```

**Exception Codes** (Interrupt=0):
| Code | Exception |
|------|-----------|
| 0 | Instruction address misaligned |
| 1 | Instruction access fault |
| 2 | Illegal instruction |
| 3 | Breakpoint (EBREAK) |
| 4 | Load address misaligned |
| 5 | Load access fault |
| 6 | Store/AMO address misaligned |
| 7 | Store/AMO access fault |
| 8 | Environment call from U-mode (ECALL) |
| 9 | Environment call from S-mode |
| 10 | Reserved |
| 11 | Environment call from M-mode |
| 12 | Instruction page fault |
| 13 | Load page fault |
| 14 | Reserved |
| 15 | Store/AMO page fault |

**Interrupt Codes** (Interrupt=1):
| Code | Interrupt |
|------|-----------|
| 0 | Reserved |
| 1 | Supervisor software interrupt |
| 2 | Reserved |
| 3 | Machine software interrupt |
| 4 | Reserved |
| 5 | Supervisor timer interrupt |
| 6 | Reserved |
| 7 | Machine timer interrupt |
| 8 | Reserved |
| 9 | Supervisor external interrupt |
| 10 | Reserved |
| 11 | Machine external interrupt |

---

#### 10. `mtval` (Machine Trap Value)
- **Address**: 0x343
- **Access**: Read-write (WARL)
- **Function**: Provides additional trap information
- **Reset Value**: 0x00000000

**Content Depends on Exception**:
- **Instruction/Load/Store address misaligned**: Faulting address
- **Instruction/Load/Store access fault**: Faulting address
- **Illegal instruction**: The illegal instruction itself
- **Breakpoint**: Faulting address
- **Other exceptions**: 0 (or implementation-defined)

---

#### 11. `mscratch` (Machine Scratch Register)
- **Address**: 0x340
- **Access**: Read-write
- **Function**: General-purpose register for machine-mode software (typically used by trap handler)
- **Reset Value**: 0x00000000

**Usage**: OpenSBI uses this to save a pointer to hart-local storage during trap handling

---

### Machine Interrupt Handling

#### 12. `mie` (Machine Interrupt Enable Register)
- **Address**: 0x304
- **Access**: Read-write
- **Function**: Individual interrupt enable bits
- **Reset Value**: 0x00000000 (all interrupts disabled)

**Bit Layout**:
```
[31:12] <reserved> = 0
[11]    MEIE = Machine external interrupt enable
[10]    <reserved> = 0
[9]     SEIE = Supervisor external interrupt enable (if S-mode implemented)
[8]     <reserved> = 0
[7]     MTIE = Machine timer interrupt enable
[6]     <reserved> = 0
[5]     STIE = Supervisor timer interrupt enable (if S-mode implemented)
[4]     <reserved> = 0
[3]     MSIE = Machine software interrupt enable
[2]     <reserved> = 0
[1]     SSIE = Supervisor software interrupt enable (if S-mode implemented)
[0]     <reserved> = 0
```

**For M-mode only** (no S-mode):
- Only bits [11], [7], [3] are relevant
- Other bits can be hardwired to 0

---

#### 13. `mip` (Machine Interrupt Pending Register)
- **Address**: 0x344
- **Access**: Read-write (but most bits are read-only or hardwired)
- **Function**: Indicates pending interrupts
- **Reset Value**: 0x00000000

**Bit Layout**: Same as `mie`
```
[11]    MEIP = Machine external interrupt pending (read-only, set by hardware)
[7]     MTIP = Machine timer interrupt pending (read-only, set by hardware)
[3]     MSIP = Machine software interrupt pending (read-only or writable)
```

**Behavior**:
- Bits [11], [7] are typically read-only and set by external hardware
- Bit [3] may be writable for software-triggered interrupts
- For initial implementation without timer/interrupts, can be hardwired to 0

---

### Machine Counter/Timers

#### 14. `mcycle` (Machine Cycle Counter)
- **Address**: 0xB00
- **Access**: Read-write
- **Function**: Counts clock cycles
- **Reset Value**: 0x00000000

**Details**:
- 64-bit counter (lower 32 bits in RV32)
- Increments every clock cycle
- Can be written by software (for testing or calibration)

---

#### 15. `mcycleh` (Upper 32 bits of `mcycle`)
- **Address**: 0xB80
- **Access**: Read-write
- **Function**: Upper 32 bits of cycle counter (RV32 only)
- **Reset Value**: 0x00000000

---

#### 16. `minstret` (Machine Instructions-Retired Counter)
- **Address**: 0xB02
- **Access**: Read-write
- **Function**: Counts instructions completed
- **Reset Value**: 0x00000000

**Details**:
- 64-bit counter (lower 32 bits in RV32)
- Increments when an instruction commits (completes without exception)
- Can be written by software

---

#### 17. `minstreth` (Upper 32 bits of `minstret`)
- **Address**: 0xB82
- **Access**: Read-write
- **Function**: Upper 32 bits of instruction counter (RV32 only)
- **Reset Value**: 0x00000000

---

### User-Mode Counter Access (Read-Only Shadows)

#### 18. `cycle` (User Cycle Counter)
- **Address**: 0xC00
- **Access**: Read-only (shadow of `mcycle`)
- **Function**: User-mode read access to cycle counter
- **Reset Value**: Same as `mcycle`

---

#### 19. `cycleh` (User Cycle Counter High)
- **Address**: 0xC80
- **Access**: Read-only (shadow of `mcycleh`)
- **Function**: User-mode read access to upper cycle counter (RV32)
- **Reset Value**: Same as `mcycleh`

---

#### 20. `time` (User Timer)
- **Address**: 0xC01
- **Access**: Read-only
- **Function**: Current time from memory-mapped timer
- **Reset Value**: 0x00000000

**Note**: May be hardwired to same value as `cycle` if no separate timer exists

---

#### 21. `timeh` (User Timer High)
- **Address**: 0xC81
- **Access**: Read-only
- **Function**: Upper 32 bits of time (RV32)
- **Reset Value**: 0x00000000

---

#### 22. `instret` (User Instructions-Retired Counter)
- **Address**: 0xC02
- **Access**: Read-only (shadow of `minstret`)
- **Function**: User-mode read access to instruction counter
- **Reset Value**: Same as `minstret`

---

#### 23. `instreth` (User Instructions-Retired Counter High)
- **Address**: 0xC82
- **Access**: Read-only (shadow of `minstreth`)
- **Function**: User-mode read access to upper instruction counter (RV32)
- **Reset Value**: Same as `minstreth`

---

### Additional CSRs Implemented (Beyond OpenSBI Minimum)

This core implements **40+ CSRs total**, including:

#### `CSR_SEED` (Entropy Source)
- **Address**: 0x015
- **Access**: Read-only
- **Function**: Returns `{2'b10, mcycle[29:0]}` — a simple entropy source for OpenSBI
- **Note**: Not a cryptographically secure random number generator

#### S-mode CSR Stubs (Read-Zero, Write-Ignore)
The following Supervisor-mode CSRs are implemented as **stubs** to allow OpenSBI to probe for S-mode support without trapping. All reads return 0; all writes are silently ignored:
- `sstatus` (0x100), `sie` (0x104), `stvec` (0x105), `scounteren` (0x106)
- `sscratch` (0x140), `sepc` (0x141), `scause` (0x142), `stval` (0x143)
- `sip` (0x144), `satp` (0x180)

#### Machine Extension Stubs (Read-Zero, Write-Ignore)
- `mstatush` (0x310), `medeleg` (0x302), `mideleg` (0x303), `mcounteren` (0x306), `mcountinhibit` (0x320)

#### PMP Configuration Stubs (Read-Zero, Write-Ignore)
- `pmpcfg0` through `pmpcfg3` (0x3A0–0x3A3)
- 16 `pmpaddr` registers (not individually listed but present in the RTL)

These stubs allow OpenSBI to perform feature detection and configuration writes without generating illegal instruction exceptions, even though the core does not actually implement S-mode or PMP hardware.

#### MEIE (Machine External Interrupt Enable) Note
- **Bit 11 of `mie`** is writable, but this core has **no external interrupt source** connected.
- Writing 1 to MEIE will not cause external interrupts to occur because no PLIC or external interrupt controller is present in the current SoC design.

---

## CSR Implementation Summary

### Mandatory for OpenSBI Boot
| CSR | Address | Type | Description |
|-----|---------|------|-------------|
| `misa` | 0x301 | RO | ISA description |
| `mhartid` | 0xF14 | RO | Hart ID |
| `mstatus` | 0x300 | RW | Status register |
| `mtvec` | 0x305 | RW | Trap vector |
| `mepc` | 0x341 | RW | Exception PC |
| `mcause` | 0x342 | RW | Trap cause |
| `mtval` | 0x343 | RW | Trap value |
| `mscratch` | 0x340 | RW | Scratch register |
| `mie` | 0x304 | RW | Interrupt enable |
| `mip` | 0x344 | RW | Interrupt pending |
| `mcycle` | 0xB00 | RW | Cycle counter (lower) |
| `mcycleh` | 0xB80 | RW | Cycle counter (upper) |
| `minstret` | 0xB02 | RW | Instret counter (lower) |
| `minstreth` | 0xB82 | RW | Instret counter (upper) |

### Optional but Recommended
| CSR | Address | Type | Description |
|-----|---------|------|-------------|
| `mvendorid` | 0xF11 | RO | Vendor ID |
| `marchid` | 0xF12 | RO | Architecture ID |
| `mimpid` | 0xF13 | RO | Implementation ID |
| `cycle` | 0xC00 | RO | User cycle counter (lower) |
| `cycleh` | 0xC80 | RO | User cycle counter (upper) |
| `instret` | 0xC02 | RO | User instret counter (lower) |
| `instreth` | 0xC82 | RO | User instret counter (upper) |
| `time` | 0xC01 | RO | User timer (lower) |
| `timeh` | 0xC81 | RO | User timer (upper) |

---

## CSR Access Instructions

### CSRRW (CSR Read/Write)
- **Opcode**: 0x73, funct3=001
- **Format**: `csrrw rd, csr, rs1`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = x[rs1]
  x[rd] = t
  ```

### CSRRS (CSR Read and Set Bits)
- **Opcode**: 0x73, funct3=010
- **Format**: `csrrs rd, csr, rs1`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = t | x[rs1]
  x[rd] = t
  ```
- **Note**: If rs1=x0, no write occurs (read-only)

### CSRRC (CSR Read and Clear Bits)
- **Opcode**: 0x73, funct3=011
- **Format**: `csrrc rd, csr, rs1`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = t & ~x[rs1]
  x[rd] = t
  ```
- **Note**: If rs1=x0, no write occurs (read-only)

### CSRRWI (CSR Read/Write Immediate)
- **Opcode**: 0x73, funct3=101
- **Format**: `csrrwi rd, csr, uimm`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = zero_extend(uimm[4:0])
  x[rd] = t
  ```

### CSRRSI (CSR Read and Set Bits Immediate)
- **Opcode**: 0x73, funct3=110
- **Format**: `csrrsi rd, csr, uimm`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = t | zero_extend(uimm[4:0])
  x[rd] = t
  ```
- **Note**: If uimm=0, no write occurs

### CSRRCI (CSR Read and Clear Bits Immediate)
- **Opcode**: 0x73, funct3=111
- **Format**: `csrrci rd, csr, uimm`
- **Operation**:
  ```
  t = CSR[csr]
  CSR[csr] = t & ~zero_extend(uimm[4:0])
  x[rd] = t
  ```
- **Note**: If uimm=0, no write occurs

---

## Trap Handling Sequence

### Taking a Trap (Hardware Action)
1. Set `mepc` ← PC (address of trapped instruction or next instruction for interrupt)
2. Set `mcause` ← trap cause code
3. Set `mtval` ← trap-specific value (address, instruction, 0)
4. Set `mstatus.MPIE` ← `mstatus.MIE`
5. Set `mstatus.MIE` ← 0 (disable interrupts)
6. Set `mstatus.MPP` ← current privilege mode
7. Set PC ← `mtvec.BASE` (or `mtvec.BASE + 4×cause` if vectored mode)
8. Set privilege mode to Machine

### Returning from Trap (`MRET` instruction)
1. Set PC ← `mepc`
2. Set `mstatus.MIE` ← `mstatus.MPIE`
3. Set privilege mode ← `mstatus.MPP`
4. Set `mstatus.MPIE` ← 1
5. Set `mstatus.MPP` ← 0 (or least-privileged mode)

---

## CSR Implementation Notes

1. **Read-Only CSRs**: Writes are ignored (WLRL - Write Legal, Read Legal) or can raise illegal instruction exception
2. **WARL Fields**: Write Any, Read Legal - illegal values are transformed to legal values
3. **WPRI Fields**: Write Preserve, Read Ignore - software should preserve values on read-modify-write
4. **64-bit Counters**: On RV32, high/low halves should be read atomically (handle overflow carefully)
5. **Privilege Checks**: Accessing higher-privilege CSRs from lower privilege should raise illegal instruction exception
6. **Unimplemented CSRs**: Should raise illegal instruction exception when accessed

---

## Verification Checklist

- [ ] All mandatory CSRs implemented and accessible
- [ ] CSR read returns correct values
- [ ] CSR write updates values correctly
- [ ] Read-only CSRs ignore writes
- [ ] CSRRS/CSRRC with rs1=x0 do not write
- [ ] CSRRSI/CSRRCI with uimm=0 do not write
- [ ] misa reports correct ISA configuration (0x40141101)
- [ ] Trap correctly updates mepc, mcause, mtval, mstatus
- [ ] MRET correctly restores state
- [ ] Cycle counter increments each cycle
- [ ] Instruction counter increments on instruction completion

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-02-26 | Initial CSR specification for OpenSBI boot |
