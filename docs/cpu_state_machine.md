# CPU State Machine

## Overview

This document describes the state machine for the non-pipelined RV32IMAZicsr CPU core. The CPU operates as a Finite State Machine (FSM) that cycles through states to fetch, decode, and execute instructions.

## State Diagram

```
         ┌─────────┐
         │  RESET  │
         └────┬────┘
              │
              v
         ┌─────────┐
    ┌───►│  FETCH  │◄────────────────────────────────────┐
    │    └────┬────┘                                     │
    │         │                                          │
    │         v                                          │
    │    ┌──────────────┐                               │
    │    │  FETCH_WAIT  │                               │
    │    └──────┬───────┘                               │
    │           │                                        │
    │           v                                        │
    │    ┌─────────┐                                    │
    │    │ DECODE  │                                    │
    │    └────┬────┘                                    │
    │         │                                          │
    │         v                                          │
    │    ┌──────────┐                                   │
    │    │ EXECUTE  │───────────────────────────────────┤ (branch/jump/most instructions)
    │    └────┬─────┘                                   │
    │         │                                          │
    │         ├─────────────────┐                       │
    │         │ (load/store)    │ (AMO*)                │
    │         v                 v                        │
    │    ┌──────────┐    ┌───────────┐                 │
    │    │  MEMORY  │    │ AMO_WRITE │                 │
    │    └────┬─────┘    └─────┬─────┘                 │
    │         │                │                        │
    │         v                v                        │
    │    ┌───────────────┐  ┌──────────────────┐       │
    │    │  MEMORY_WAIT  │  │ AMO_WRITE_WAIT   │       │
    │    └───────┬───────┘  └────────┬─────────┘       │
    │            │                   │                  │
    │            └─────────┬─────────┘                 │
    │                      v                            │
    │    ┌────────────┐                                │
    │    │ WRITEBACK  │────────────────────────────────┘
    │    └────────────┘
    │            │
    │            │ (exception/interrupt)
    │            v
    │    ┌──────────┐
    └────┤   TRAP   │
         └──────────┘
```

## State Descriptions

### RESET
- **Entry Condition**: System reset signal is asserted (active low)
- **Actions**:
  - Initialize PC to reset vector (0x00000000)
  - Clear all registers
  - Initialize CSRs to default values
  - Set mstatus to machine mode
- **Next State**: FETCH

### FETCH
- **Entry Condition**: Previous instruction completed or after reset
- **Actions**:
  - Assert bus read request with PC as address
  - Set bus transaction type to instruction fetch
- **Next State**: FETCH_WAIT

### FETCH_WAIT
- **Entry Condition**: Bus request issued
- **Actions**:
  - Wait for bus ready signal
  - Capture instruction from bus data lines
  - Latch instruction into Instruction Register (IR)
- **Next State**: DECODE (when bus ready asserted)

### DECODE
- **Entry Condition**: Instruction received from memory
- **Actions**:
  - Parse instruction format (R/I/S/B/U/J)
  - Extract opcode, funct3, funct7, rd, rs1, rs2
  - Generate immediate value based on format
  - Read register file for rs1 and rs2
  - Determine instruction type and required execution unit
  - Generate control signals for EXECUTE stage
- **Next State**: 
  - EXECUTE (for all instructions)
  - TRAP (if illegal instruction detected)

### EXECUTE
- **Entry Condition**: Instruction decoded and operands ready
- **Actions**:
  - **Arithmetic/Logical (RV32I)**:
    - Perform ALU operation (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
    - Store result in temporary register
  - **Multiply/Divide (M-extension)**:
    - Start multi-cycle multiply or divide operation
    - Wait for operation to complete
  - **Branch**:
    - Evaluate branch condition
    - Calculate branch target (PC + imm)
    - Update PC if branch taken
  - **Jump (JAL/JALR)**:
    - Calculate jump target
    - Store return address (PC + 4) in rd
    - Update PC
  - **Load Upper Immediate (LUI/AUIPC)**:
    - Calculate immediate value
    - Store in temporary register
  - **Atomic (A-extension)**:
    - Perform atomic read-modify-write
    - Generate memory transaction
  - **CSR Instructions (Zicsr)**:
    - Read CSR value
    - Perform CSR operation (read/write/set/clear)
    - Check privilege level
- **Next State**:
  - MEMORY (if load/store instruction)
  - WRITEBACK (if result needs to be written to register)
  - FETCH (if branch taken or jump)
  - TRAP (if exception occurs: illegal CSR access, misaligned access, etc.)

### MEMORY
- **Entry Condition**: Load or store instruction in EXECUTE
- **Actions**:
  - Calculate effective address (rs1 + imm)
  - For **Load** (LB, LH, LW, LBU, LHU):
    - Assert bus read request with calculated address
    - Specify data width (byte, half-word, word)
  - For **Store** (SB, SH, SW):
    - Assert bus write request with calculated address
    - Drive data from rs2 onto bus
    - Specify data width
  - For **Atomic** (LR, SC, AMO*):
    - Assert atomic bus transaction
    - Perform lock/unlock as needed
- **Next State**: MEMORY_WAIT

### MEMORY_WAIT
- **Entry Condition**: Memory transaction initiated
- **Actions**:
  - Wait for bus ready signal
  - For **Load**: Capture data from bus and latch into temporary register
  - For **Store**: Wait for write acknowledgment
  - For **Atomic**: Capture success/failure status
- **Next State**: 
  - WRITEBACK (for loads)
  - FETCH (for stores)
  - TRAP (if bus error or misaligned access)

### AMO_WRITE
- **Entry Condition**: Atomic memory operation (AMO*) after read-modify in EXECUTE
- **Actions**:
  - Present modified (post-ALU) value and effective address on bus
  - Assert bus write request with appropriate byte enables
  - Hold all signals stable until bus accepts the transaction
- **Next State**: AMO_WRITE_WAIT

### AMO_WRITE_WAIT
- **Entry Condition**: AMO write transaction issued
- **Actions**:
  - Wait for bus ready signal confirming the write completed
  - The original loaded value (captured during the preceding read) is already
    latched for writeback to `rd`
- **Next State**:
  - WRITEBACK (write original loaded value to `rd`, then advance PC)
  - TRAP (if bus error occurs)

### WRITEBACK
- **Entry Condition**: Instruction execution completed with result
- **Actions**:
  - Write result to destination register (rd)
  - Ensure x0 remains hardwired to zero (write to x0 is ignored)
  - Increment PC (PC = PC + 4) if not already updated
  - Update instruction counter (minstret CSR)
- **Next State**: FETCH

### TRAP
- **Entry Condition**: Exception or interrupt detected
- **Actions**:
  - Save current PC to mepc CSR
  - Save exception cause to mcause CSR
  - Save additional info to mtval CSR (e.g., bad address, illegal instruction)
  - Set appropriate bits in mstatus
  - Calculate trap vector address from mtvec CSR
  - Update PC to trap handler address
- **Exception Types**:
  - Illegal instruction (unsupported opcode)
  - Misaligned instruction fetch
  - Misaligned load/store
  - Bus access fault
  - Illegal CSR access
  - Privilege violation
  - ECALL/EBREAK instructions
- **Next State**: FETCH (begins executing trap handler)

## State Transition Table

| Current State | Condition | Next State |
|---------------|-----------|------------|
| RESET | Always | FETCH |
| FETCH | Always | FETCH_WAIT |
| FETCH_WAIT | bus_ready | DECODE |
| DECODE | valid_instruction | EXECUTE |
| DECODE | illegal_instruction | TRAP |
| EXECUTE | load/store | MEMORY |
| EXECUTE | AMO* | AMO_WRITE |
| EXECUTE | branch_taken | FETCH |
| EXECUTE | jump | FETCH |
| EXECUTE | other | WRITEBACK |
| EXECUTE | exception | TRAP |
| MEMORY | Always | MEMORY_WAIT |
| MEMORY_WAIT | bus_ready & load | WRITEBACK |
| MEMORY_WAIT | bus_ready & store | FETCH |
| MEMORY_WAIT | bus_error | TRAP |
| AMO_WRITE | Always | AMO_WRITE_WAIT |
| AMO_WRITE_WAIT | bus_ready | WRITEBACK |
| AMO_WRITE_WAIT | bus_error | TRAP |
| WRITEBACK | Always | FETCH |
| TRAP | Always | FETCH |

## Timing Considerations

- **Minimum Instruction Execution**: 4 cycles (FETCH → FETCH_WAIT → DECODE → EXECUTE → WRITEBACK → FETCH)
- **Load Instruction**: 6 cycles (includes MEMORY and MEMORY_WAIT)
- **Store Instruction**: 5 cycles (no WRITEBACK needed)
- **Branch Taken**: 4 cycles
- **Branch Not Taken**: 4 cycles
- **Multiply/Divide**: 4 + N cycles (N = operation latency, typically 32 cycles for div)

## Control Signals Generated by State Machine

The state machine generates the following control signals:

- `pc_write_enable`: Update program counter
- `pc_source`: Select PC source (PC+4, branch target, jump target, trap vector)
- `ir_write_enable`: Latch instruction into IR
- `reg_write_enable`: Write result to register file
- `alu_op`: ALU operation selector
- `mem_read`: Assert memory read
- `mem_write`: Assert memory write
- `mem_width`: Memory transaction width (byte/half/word)
- `csr_read_enable`: Read from CSR
- `csr_write_enable`: Write to CSR
- `bus_req`: Bus transaction request
- `bus_addr_source`: Select bus address (PC or ALU result)

## Notes

- This is a **non-pipelined** design for simplicity
- All instructions complete before the next instruction begins
- No forwarding or hazard detection logic needed
- Bus interface uses simple ready/valid handshake
- Multi-cycle operations (multiply/divide) stall in EXECUTE state
