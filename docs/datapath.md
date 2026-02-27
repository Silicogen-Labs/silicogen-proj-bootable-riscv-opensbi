# CPU Datapath

## Overview

This document describes the datapath for the RV32IMAZicsr CPU core. The datapath consists of all functional units and data storage elements required to execute instructions.

## High-Level Datapath Diagram

```
                    ┌──────────────────────────────────────────────────┐
                    │                   CPU CORE                       │
                    │                                                  │
                    │  ┌────────────┐       ┌───────────────────┐    │
                    │  │   PC Reg   │       │   Control Unit    │    │
                    │  │  (32-bit)  │       │  (State Machine)  │    │
                    │  └──────┬─────┘       └─────────┬─────────┘    │
                    │         │                       │              │
                    │         v                       │ (control)    │
                    │  ┌─────────────┐               v              │
                    │  │  PC + 4     │        ┌──────────────┐      │
                    │  └──────┬──────┘        │   Decoder    │      │
                    │         │               └──────┬───────┘      │
                    │         │                      │              │
ibus ◄──────────────│─────────┘                     │              │
(instruction bus)   │                               │              │
                    │                               v              │
                    │                    ┌─────────────────┐       │
                    │                    │ Instruction Reg │       │
                    │                    │   (IR, 32-bit)  │       │
                    │                    └────────┬────────┘       │
                    │                             │                │
                    │                 ┌───────────┼───────────┐   │
                    │                 │           │           │   │
                    │                 v           v           v   │
                    │             ┌────────┐  ┌────────┐  ┌─────┐│
                    │             │  rs1   │  │  rs2   │  │ rd  ││
                    │             │(5-bit) │  │(5-bit) │  │(5)  ││
                    │             └───┬────┘  └───┬────┘  └──┬──┘│
                    │                 │           │          │   │
                    │                 v           v          │   │
                    │           ┌─────────────────────────┐  │   │
                    │           │   Register File         │  │   │
                    │           │   32 x 32-bit regs      │  │   │
                    │           │   x0 hardwired to 0     │  │   │
                    │           │   2 read, 1 write port  │  │   │
                    │           └──────┬──────┬───────────┘  │   │
                    │                  │      │              │   │
                    │               rs1_data  rs2_data       │   │
                    │                  │      │              │   │
                    │                  v      v              │   │
                    │              ┌──────────────┐          │   │
                    │              │  Immediate   │          │   │
                    │              │  Generator   │          │   │
                    │              └──────┬───────┘          │   │
                    │                     │ imm              │   │
                    │                     v                  │   │
                    │              ┌─────────────────┐       │   │
                    │              │   Operand Mux   │       │   │
                    │              │  (rs2 or imm)   │       │   │
                    │              └──────┬──────────┘       │   │
                    │                     │                  │   │
                    │                operand_a  operand_b    │   │
                    │                     │      │           │   │
                    │                     v      v           │   │
                    │              ┌─────────────────┐       │   │
                    │              │       ALU       │       │   │
                    │              │   (32-bit)      │       │   │
                    │              │  ADD,SUB,AND... │       │   │
                    │              └──────┬──────────┘       │   │
                    │                     │ alu_result       │   │
                    │                     v                  │   │
                    │              ┌─────────────────┐       │   │
                    │              │    MUL/DIV      │       │   │
                    │              │  (M-extension)  │       │   │
                    │              └──────┬──────────┘       │   │
                    │                     │ muldiv_result    │   │
                    │                     v                  │   │
                    │              ┌─────────────────┐       │   │
                    │              │   CSR File      │       │   │
                    │              │  (Zicsr ext)    │       │   │
                    │              └──────┬──────────┘       │   │
                    │                     │ csr_data         │   │
                    │                     v                  │   │
                    │              ┌─────────────────┐       │   │
                    │              │  Writeback Mux  │       │   │
                    │              │ (select result) │       │   │
                    │              └──────┬──────────┘       │   │
                    │                     │ write_data       │   │
                    │                     │                  │   │
                    │                     └──────────────────┘   │
                    │                             │              │
                    │                             v              │
                    │                      (back to reg file)    │
                    │                                            │
                    │    alu_result ──────────► dbus Address     │
                    │                                            │
dbus ◄──────────────│────────────────────────────────────────────┘
(data bus)
                    └────────────────────────────────────────────┘
```

## Datapath Components

### 1. Program Counter (PC)
- **Width**: 32 bits
- **Function**: Holds address of current instruction
- **Reset Value**: 0x00000000
- **Updates**:
  - Sequential: PC ← PC + 4
  - Branch: PC ← PC + imm (if condition true)
  - Jump: PC ← PC + imm (JAL) or rs1 + imm (JALR)
  - Trap: PC ← mtvec

### 2. Instruction Register (IR)
- **Width**: 32 bits
- **Function**: Holds current instruction being executed
- **Update**: Loaded from memory during FETCH_WAIT state

### 3. Register File
- **Configuration**: 32 registers × 32 bits
- **Registers**:
  - `x0`: Hardwired to 0 (reads always return 0, writes are ignored)
  - `x1-x31`: General purpose registers
- **Ports**:
  - Read Port A: Outputs rs1_data (32-bit)
  - Read Port B: Outputs rs2_data (32-bit)
  - Write Port: Inputs write_data (32-bit), rd address (5-bit), write_enable
- **Read**: Combinational (asynchronous read)
- **Write**: Synchronous (on rising clock edge when write_enable asserted)

### 4. Decoder
- **Inputs**: 32-bit instruction from IR
- **Outputs**:
  - `opcode` (7 bits)
  - `funct3` (3 bits)
  - `funct7` (7 bits)
  - `rd` (5 bits) - destination register
  - `rs1` (5 bits) - source register 1
  - `rs2` (5 bits) - source register 2
  - `imm` (32 bits) - sign-extended immediate

### 5. Immediate Generator
- **Function**: Extract and sign-extend immediate values based on instruction format
- **Formats**:
  - **I-type**: imm[11:0] = inst[31:20]
  - **S-type**: imm[11:0] = {inst[31:25], inst[11:7]}
  - **B-type**: imm[12:0] = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
  - **U-type**: imm[31:0] = {inst[31:12], 12'b0}
  - **J-type**: imm[20:0] = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
- **Output**: 32-bit sign-extended immediate

### 6. Arithmetic Logic Unit (ALU)
- **Width**: 32 bits
- **Operations** (RV32I):
  - `ADD`: operand_a + operand_b
  - `SUB`: operand_a - operand_b
  - `AND`: operand_a & operand_b
  - `OR`: operand_a | operand_b
  - `XOR`: operand_a ^ operand_b
  - `SLL`: operand_a << operand_b[4:0] (logical left shift)
  - `SRL`: operand_a >> operand_b[4:0] (logical right shift)
  - `SRA`: operand_a >>> operand_b[4:0] (arithmetic right shift)
  - `SLT`: (signed)operand_a < (signed)operand_b ? 1 : 0
  - `SLTU`: (unsigned)operand_a < (unsigned)operand_b ? 1 : 0
  - `PASS_A`: operand_a (used for LUI/AUIPC)
  - `PASS_B`: operand_b
- **Inputs**:
  - `operand_a` (32-bit): typically rs1_data
  - `operand_b` (32-bit): rs2_data or immediate
  - `alu_op` (4-bit): operation selector
- **Outputs**:
  - `alu_result` (32-bit)
  - `alu_zero`: result == 0
  - `alu_negative`: result[31]

### 7. Multiplier/Divider Unit (M-Extension)
- **Operations**:
  - `MUL`: Lower 32 bits of rs1 × rs2 (signed × signed)
  - `MULH`: Upper 32 bits of rs1 × rs2 (signed × signed)
  - `MULHU`: Upper 32 bits of rs1 × rs2 (unsigned × unsigned)
  - `MULHSU`: Upper 32 bits of rs1 × rs2 (signed × unsigned)
  - `DIV`: rs1 ÷ rs2 (signed)
  - `DIVU`: rs1 ÷ rs2 (unsigned)
  - `REM`: rs1 % rs2 (signed remainder)
  - `REMU`: rs1 % rs2 (unsigned remainder)
- **Implementation**: Multi-cycle (32 cycles for division)
- **Inputs**:
  - `operand_a` (32-bit)
  - `operand_b` (32-bit)
  - `muldiv_op` (3-bit)
  - `start`: Start operation
- **Outputs**:
  - `muldiv_result` (32-bit)
  - `done`: Operation complete
  - `busy`: Operation in progress (used to stall the core)

### 8. CSR File (Zicsr Extension)
- **Function**: Control and Status Registers
- **Size**: Sparse array (only implemented CSRs exist)
- **Operations**:
  - `CSRRW`: CSR read/write
  - `CSRRS`: CSR read and set bits
  - `CSRRC`: CSR read and clear bits
  - `CSRRWI`: CSR read/write immediate
  - `CSRRSI`: CSR read and set bits immediate
  - `CSRRCI`: CSR read and clear bits immediate
- **Required CSRs**: See `csr_requirements.md`
- **Inputs**:
  - `csr_addr` (12-bit)
  - `csr_wdata` (32-bit)
  - `csr_op` (2-bit)
  - `csr_we` (write enable)
- **Outputs**:
  - `csr_rdata` (32-bit)

### 9. Branch Condition Unit
- **Function**: Evaluate branch conditions
- **Operations**:
  - `BEQ`: rs1 == rs2
  - `BNE`: rs1 != rs2
  - `BLT`: (signed)rs1 < (signed)rs2
  - `BGE`: (signed)rs1 >= (signed)rs2
  - `BLTU`: (unsigned)rs1 < (unsigned)rs2
  - `BGEU`: (unsigned)rs1 >= (unsigned)rs2
- **Inputs**: rs1_data, rs2_data, funct3
- **Output**: `branch_taken` (1-bit)

### 10. Multiplexers

#### Instruction Bus Address (ibus)
- **Function**: Carries PC directly to the instruction memory port
- **Input**: PC register (32-bit)
- **Output**: ibus_addr (32-bit) — always word-aligned (PC[1:0] == 2'b00)
- **Note**: No mux required; PC is hardwired to the ibus address port

#### Data Bus Address Multiplexer (dbus)
- **Function**: Select address for data memory / MMIO transactions
- **Inputs**:
  - alu_result (for load, store, and AMO data accesses)
- **Output**: dbus_addr (32-bit)

#### Operand B Multiplexer
- **Function**: Select second ALU operand
- **Inputs**:
  - rs2_data (for R-type instructions)
  - immediate (for I-type, S-type, etc.)
- **Output**: operand_b (32-bit)

#### Writeback Multiplexer
- **Function**: Select data to write back to register file
- **Inputs**:
  - alu_result (arithmetic/logical operations)
  - muldiv_result (multiply/divide operations)
  - mem_rdata (load instructions)
  - pc_plus_4 (JAL/JALR return address)
  - csr_rdata (CSR read)
- **Output**: write_data (32-bit)

#### PC Source Multiplexer
- **Function**: Select next PC value
- **Inputs**:
  - pc_plus_4 (sequential execution)
  - branch_target (PC + imm for branches)
  - jump_target (JAL: PC + imm, JALR: rs1 + imm)
  - trap_vector (from mtvec CSR)
- **Output**: next_pc (32-bit)

## Data Flow for Common Instructions

### Example 1: ADD x3, x1, x2
```
1. FETCH: PC → ibus → IR receives instruction
2. DECODE: 
   - Extract rs1=x1, rs2=x2, rd=x3, opcode=ADD
   - Read x1 → rs1_data, Read x2 → rs2_data
3. EXECUTE:
   - operand_a = rs1_data, operand_b = rs2_data
   - ALU performs: alu_result = operand_a + operand_b
4. WRITEBACK:
   - write_data = alu_result
   - Write write_data to x3 in register file
   - PC = PC + 4
```

### Example 2: LW x5, 8(x2)
```
1. FETCH: PC → ibus → IR receives instruction
2. DECODE:
   - Extract rs1=x2, rd=x5, imm=8, opcode=LW
   - Read x2 → rs1_data
3. EXECUTE:
   - operand_a = rs1_data, operand_b = imm (8)
   - ALU performs: alu_result = operand_a + operand_b (effective address)
4. MEMORY:
   - dbus Address = alu_result
   - Assert dbus read
5. MEMORY_WAIT:
   - Wait for dbus_ready
   - Capture dbus_rdata → mem_rdata
6. WRITEBACK:
   - write_data = mem_rdata
   - Write write_data to x5
   - PC = PC + 4
```

### Example 3: BEQ x1, x2, offset
```
1. FETCH: PC → ibus → IR receives instruction
2. DECODE:
   - Extract rs1=x1, rs2=x2, imm=offset, opcode=BEQ
   - Read x1 → rs1_data, Read x2 → rs2_data
3. EXECUTE:
   - Branch condition unit: branch_taken = (rs1_data == rs2_data)
   - Calculate branch_target = PC + imm
   - If branch_taken: PC = branch_target
   - Else: PC = PC + 4
4. Go to FETCH (no writeback needed)
```

## Atomic Operations (A-Extension)

For atomic operations (LR.W, SC.W, AMO*), the implementation uses:
- **Standard dbus interface**: No special atomic bus signals; atomics are implemented as two-phase transactions (read via MEMORY/MEMORY_WAIT, then write via AMO_WRITE/AMO_WRITE_WAIT)
- **AMO write-back register**: Stores the computed write value (rs2 or ALU result of old value + rs2, etc.) during EXECUTE for later use in AMO_WRITE
- **No hardware reservation register**: LR/SC semantics are handled by the bus/memory controller if needed (not currently implemented in this simple single-core design)

## Critical Timing Paths

For FPGA synthesis, these are the longest combinational paths:
1. **ALU Path**: Register file → ALU → Writeback mux → Register file
2. **Branch Path**: Register file → Branch condition → PC mux → PC
3. **Data Memory Address**: Register file → ALU → dbus address

## Split Bus Architecture

The CPU exposes two independent bus interfaces to the SoC:

| Bus | Direction | Address Source | Used In States |
|-----|-----------|----------------|----------------|
| **ibus** (instruction) | read-only | PC register | FETCH, FETCH_WAIT |
| **dbus** (data) | read/write | ALU result | MEMORY, MEMORY_WAIT, AMO_WRITE, AMO_WRITE_WAIT |

Both buses use the same ready/valid handshake protocol. Because the CPU is
non-pipelined, only one bus is active at any given time — they will never
contend — but keeping them separate simplifies address decode and allows a
Harvard-style cache split in future revisions.

## Register Naming (ABI Convention)

| Register | ABI Name | Description |
|----------|----------|-------------|
| x0 | zero | Hardwired zero |
| x1 | ra | Return address |
| x2 | sp | Stack pointer |
| x3 | gp | Global pointer |
| x4 | tp | Thread pointer |
| x5-x7 | t0-t2 | Temporaries |
| x8 | s0/fp | Saved register / Frame pointer |
| x9 | s1 | Saved register |
| x10-x11 | a0-a1 | Function arguments / Return values |
| x12-x17 | a2-a7 | Function arguments |
| x18-x27 | s2-s11 | Saved registers |
| x28-x31 | t3-t6 | Temporaries |

## Notes
- All data paths are 32-bit wide
- No forwarding or bypassing (non-pipelined)
- Multi-cycle operations stall the entire pipeline
- Split ibus/dbus: instruction fetches use ibus (PC as address); all data
  memory accesses (load, store, AMO) use dbus (ALU result as address)
- Both bus interfaces use synchronous ready/valid handshake
