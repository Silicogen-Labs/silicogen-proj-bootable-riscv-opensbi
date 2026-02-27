# Memory Map

## Overview

This document defines the complete memory address space for the Bootble RISC-V SoC. The system uses a 32-bit address space with memory-mapped I/O.

## Complete Memory Map

```
0x00000000 ┌──────────────────────────────────┐
           │                                  │
           │            RAM (4MB)             │
           │      Main System Memory          │
           │     (code + data + stack)        │
           │                                  │
0x003FFFFF └──────────────────────────────────┘
           │                                  │
           │        Reserved / Unused         │
           │                                  │
0x02000000 ┌──────────────────────────────────┐
           │     CLINT Timer Registers        │
           │  mtime / mtimecmp (RISC-V std)   │
0x02FFFFFF └──────────────────────────────────┘
           │                                  │
           │        Reserved / Unused         │
           │                                  │
0x10000000 ┌──────────────────────────────────┐
           │     UART 16550a Registers        │
           │   (256 bytes, reg-shift=2)       │
0x100000FF └──────────────────────────────────┘
           │                                  │
           │        Reserved / Unused         │
           │       (rest of address space)    │
           │                                  │
0xFFFFFFFF └──────────────────────────────────┘
```

---

## Memory Region Detailed Specifications

### 1. RAM (Main Memory)

- **Base Address**: `0x00000000`
- **End Address**: `0x003FFFFF`
- **Size**: 4 MB (4,194,304 bytes)
- **Access**: Read/Write
- **Width**: 32-bit word-aligned, supports byte/halfword/word accesses
- **Purpose**: 
  - OpenSBI firmware code
  - Data storage
  - Stack
  - Heap

#### RAM Memory Layout (Software Convention)

```
0x00000000 ┌──────────────────────────────────┐
           │   OpenSBI Code (.text)           │
           │                                  │
0x00010000 ├──────────────────────────────────┤ (Approximate)
           │   OpenSBI Data (.data, .bss)     │
           │                                  │
0x00020000 ├──────────────────────────────────┤ (Approximate)
           │                                  │
           │   Available for Payload          │
           │   (Future OS kernel, etc.)       │
           │                                  │
0x003F0000 ├──────────────────────────────────┤
           │   Stack (grows downward)         │
           │   Initial SP = 0x00400000        │
0x003FFFFF └──────────────────────────────────┘
```

**Notes**:
- Byte-addressable
- Supports unaligned accesses (but may incur performance penalty)
- Misaligned accesses across word boundaries should trigger exception
- Memory is initialized from a hex/binary file during simulation
- Reset vector at `0x00000000` (CPU starts executing from here)

---

### 2. CLINT Timer

- **Base Address**: `0x02000000`
- **End Address**: `0x02FFFFFF`
- **Size**: 16 MB region (RISC-V standard CLINT address space)
- **Compatible With**: RISC-V CLINT (Core Local Interruptor)
- **Purpose**: Provides `mtime` and `mtimecmp` for timer interrupts

#### Timer Register Map

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0x0200BFF8` | `mtime` (low) | R/W | Machine timer counter, lower 32 bits |
| `0x0200BFFC` | `mtime` (high) | R/W | Machine timer counter, upper 32 bits |
| `0x02004000` | `mtimecmp` (low) | R/W | Timer compare register, lower 32 bits |
| `0x02004004` | `mtimecmp` (high) | R/W | Timer compare register, upper 32 bits |

#### Timer Interrupt Behavior

- `timer_irq` is asserted when `mtime >= mtimecmp`
- Writing to `mtimecmp` clears the interrupt
- `mtime` increments every clock cycle
- OpenSBI uses this for SBI timer extensions

---

### 3. UART 16550a (Serial Console)

- **Base Address**: `0x10000000`
- **End Address**: `0x100000FF`
- **Size**: 256 bytes
- **Compatible With**: NS16550A standard UART
- **Purpose**: Console output (and optionally input)

#### UART Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | RBR/THR/DLL | R/W | Receiver Buffer (R) / Transmitter Holding (W) / Divisor Latch LSB (when DLAB=1) |
| `0x01` | IER/DLM | R/W | Interrupt Enable (R/W) / Divisor Latch MSB (when DLAB=1) |
| `0x02` | IIR/FCR | R/W | Interrupt Identification (R) / FIFO Control (W) |
| `0x03` | LCR | R/W | Line Control Register |
| `0x04` | MCR | R/W | Modem Control Register |
| `0x05` | LSR | R | Line Status Register |
| `0x06` | MSR | R | Modem Status Register |
| `0x07` | SCR | R/W | Scratch Register |

#### Register Descriptions

##### 0x00: RBR (Receiver Buffer Register) - Read Only
- **Function**: Read received character
- **Bits [7:0]**: Received data byte
- **Note**: For initial implementation (transmit-only), this may return 0

##### 0x00: THR (Transmitter Holding Register) - Write Only
- **Function**: Write character to transmit
- **Bits [7:0]**: Data byte to transmit
- **Behavior**: Writing to this register queues character for transmission

##### 0x00: DLL (Divisor Latch LSB) - Read/Write (when DLAB=1)
- **Function**: Baud rate divisor low byte
- **Bits [7:0]**: Divisor LSB
- **Formula**: Baud Rate = Clock Frequency / (16 × Divisor)

##### 0x01: IER (Interrupt Enable Register) - Read/Write
- **Bit 0**: Enable Received Data Available Interrupt
- **Bit 1**: Enable Transmitter Holding Register Empty Interrupt
- **Bit 2**: Enable Receiver Line Status Interrupt
- **Bit 3**: Enable Modem Status Interrupt
- **Bits [7:4]**: Reserved (0)
- **Note**: For initial implementation, interrupts may not be implemented

##### 0x01: DLM (Divisor Latch MSB) - Read/Write (when DLAB=1)
- **Function**: Baud rate divisor high byte
- **Bits [7:0]**: Divisor MSB

##### 0x02: IIR (Interrupt Identification Register) - Read Only
- **Bits [3:0]**: Interrupt identification bits
- **Bits [7:6]**: FIFO enabled status
- **Note**: For initial implementation, may return no interrupt pending

##### 0x02: FCR (FIFO Control Register) - Write Only
- **Bit 0**: FIFO Enable
- **Bit 1**: Receiver FIFO Reset
- **Bit 2**: Transmitter FIFO Reset
- **Bits [7:3]**: FIFO threshold and DMA mode
- **Note**: For initial implementation, FIFOs may not be implemented

##### 0x03: LCR (Line Control Register) - Read/Write
- **Bits [1:0]**: Word length (11 = 8 bits, typical)
- **Bit 2**: Stop bits (0 = 1 stop bit, 1 = 2 stop bits)
- **Bit 3**: Parity enable
- **Bit 4**: Even parity select
- **Bit 5**: Stick parity
- **Bit 6**: Break control
- **Bit 7**: DLAB (Divisor Latch Access Bit)

##### 0x04: MCR (Modem Control Register) - Read/Write
- **Bit 0**: Data Terminal Ready (DTR)
- **Bit 1**: Request To Send (RTS)
- **Bit 2**: OUT1
- **Bit 3**: OUT2
- **Bit 4**: Loopback mode
- **Bits [7:5]**: Reserved
- **Note**: For initial implementation, these may not have functional effect

##### 0x05: LSR (Line Status Register) - Read Only
- **Bit 0**: Data Ready (DR) - Received data available
- **Bit 1**: Overrun Error (OE)
- **Bit 2**: Parity Error (PE)
- **Bit 3**: Framing Error (FE)
- **Bit 4**: Break Interrupt (BI)
- **Bit 5**: Transmitter Holding Register Empty (THRE) - Ready for next char
- **Bit 6**: Transmitter Empty (TEMT) - Transmitter completely idle
- **Bit 7**: Error in RCVR FIFO
- **Critical For OpenSBI**: Bit 5 (THRE) must be 1 when UART is ready to accept data

##### 0x06: MSR (Modem Status Register) - Read Only
- **Bits [3:0]**: Delta status bits
- **Bits [7:4]**: Current modem control input states
- **Note**: For initial implementation, may return fixed values

##### 0x07: SCR (Scratch Register) - Read/Write
- **Bits [7:0]**: Scratch data (not used by hardware)
- **Purpose**: Software can use this for testing

#### UART Configuration for OpenSBI

OpenSBI expects the following UART configuration:
- **Baud Rate**: Typically 115200 (but configurable via device tree)
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **Clock Frequency**: Specified in device tree (`clock-frequency` property)
- **Register Width**: 32-bit word-aligned
- **Register Stride**: `reg-shift = <2>` — registers spaced 4 bytes apart (e.g. LSR at `0x10000014`)
- **Register I/O Width**: `reg-io-width = <4>` (32-bit reads/writes)
- **Hardware Decode**: `addr[4:2]` extracts the register index (0–7)

#### Minimal UART Implementation for Boot

For initial OpenSBI boot, the UART can be simplified to:
- **Transmit-only**: Only THR (0x00) and LSR (0x05) need to work
- **LSR Bit 5 (THRE)**: Must return 1 when ready to accept new character
- **THR**: Writing to this outputs character to console

---

## Address Decoding Logic

The bus arbiter uses the following logic to route addresses:

```systemverilog
// Address decoding
always_comb begin
    if (bus_addr >= 32'h00000000 && bus_addr < 32'h00400000) begin
        // RAM region
        ram_select   = 1'b1;
        uart_select  = 1'b0;
        timer_select = 1'b0;
    end else if (bus_addr >= 32'h02000000 && bus_addr < 32'h03000000) begin
        // CLINT timer region
        ram_select   = 1'b0;
        uart_select  = 1'b0;
        timer_select = 1'b1;
    end else if (bus_addr >= 32'h10000000 && bus_addr < 32'h10000100) begin
        // UART region
        ram_select   = 1'b0;
        uart_select  = 1'b1;
        timer_select = 1'b0;
    end else begin
        // Unmapped address - generate bus error
        ram_select   = 1'b0;
        uart_select  = 1'b0;
        timer_select = 1'b0;
        bus_error    = 1'b1;
    end
end
```

---

## Bus Protocol

### Bus Signals

- **Address**: 32-bit
- **Data**: 32-bit
- **Write Enable**: 1-bit (0 = read, 1 = write)
- **Byte Enable**: 4-bit (for sub-word accesses)
- **Request**: 1-bit (transaction start)
- **Ready**: 1-bit (transaction complete)

### Transaction Types

#### Word Write (32-bit)
```
Cycle 0: Assert addr, wdata, we=1, be=4'b1111, req=1
Cycle 1: Wait for ready=1, then deassert req
```

#### Word Read (32-bit)
```
Cycle 0: Assert addr, we=0, be=4'b1111, req=1
Cycle 1: Wait for ready=1, capture rdata, then deassert req
```

#### Byte Write (8-bit)
```
Cycle 0: Assert addr, wdata (in appropriate byte lane), we=1, be (one bit set), req=1
Cycle 1: Wait for ready=1, then deassert req
```

#### Byte Read (8-bit)
```
Cycle 0: Assert addr, we=0, be (one bit set), req=1
Cycle 1: Wait for ready=1, capture rdata (from appropriate byte lane), then deassert req
```

---

## Memory Access Permissions

| Region | Execute | Read | Write | Cacheable |
|--------|---------|------|-------|-----------|
| RAM | Yes | Yes | Yes | Yes (future) |
| Timer (CLINT) | No | Yes | Yes | No |
| UART | No | Yes | Yes | No |
| Unmapped | No | No | No | No (causes exception) |

---

## Exception Conditions

- **Unmapped Address**: Access to address outside defined regions → Load/Store Access Fault
- **Misaligned Access**: 
  - Word access to non-word-aligned address → Load/Store Address Misaligned
  - Half-word access to odd address → Load/Store Address Misaligned
- **Instruction Fetch from UART**: Should ideally cause Instruction Access Fault
- **Write to ROM** (if implemented): Store Access Fault

---

## Reset Vector

- **Address**: `0x00000000`
- **Purpose**: CPU begins execution from this address after reset
- **Content**: Should contain OpenSBI boot code entry point

---

## Device Tree Representation

The memory map will be described to OpenSBI via device tree:

```dts
memory@0 {
    device_type = "memory";
    reg = <0x00000000 0x00400000>;  // Base=0x0, Size=4MB
};

clint@2000000 {
    compatible = "riscv,clint0";
    reg = <0x02000000 0x10000>;     // Base=0x02000000
    interrupts-extended = <&cpu0_intc 3 &cpu0_intc 7>;
};

uart@10000000 {
    compatible = "ns16550a";
    reg = <0x10000000 0x100>;       // Base=0x10000000, Size=256 bytes
    clock-frequency = <50000000>;   // 50 MHz
    reg-shift = <2>;                // Registers spaced 4 bytes apart (addr[4:2])
    reg-io-width = <4>;             // 32-bit register access
};
```

---

## Future Expansion

Reserved address ranges for future peripherals:
- `0x10000100 - 0x100001FF`: Reserved for second UART
- `0x10001000 - 0x10001FFF`: Reserved for timer/counter
- `0x10002000 - 0x10002FFF`: Reserved for interrupt controller (PLIC)
- `0x10003000 - 0x10003FFF`: Reserved for GPIO
- `0x20000000 - 0x2FFFFFFF`: Reserved for additional RAM/ROM
- `0x40000000 - 0x4FFFFFFF`: Reserved for peripherals

---

## Verification Checklist

- [ ] RAM responds correctly to word/halfword/byte accesses
- [ ] UART registers are accessible at correct offsets
- [ ] Bus error generated for unmapped addresses
- [ ] Address decoder prioritizes regions correctly
- [ ] LSR register returns correct THRE status
- [ ] THR writes output characters correctly
- [ ] Reset vector points to valid RAM location

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-02-26 | Initial memory map specification |
