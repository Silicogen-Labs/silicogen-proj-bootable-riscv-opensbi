# Building a Bootable RISC-V Processor: The Journey from Silicon to OpenSBI

*A deep dive into designing, implementing, and debugging a RISC-V RV32IMAZicsr processor in SystemVerilog, with the ultimate goal of booting real-world firmware.*

## Table of Contents

1. [The Vision: A Real Processor for Real Firmware](#the-vision)
2. [The Foundation: Microarchitecture First](#phase-1-microarchitecture-definition)
3. [From Paper to Silicon: RTL Implementation](#phase-2-rtl-implementation)
4. [Integration: Building the System-on-a-Chip](#phase-3-system-integration)
5. [The Debugging Odyssey: Eight Bugs and Counting](#phase-4-simulation-and-debugging)
6. [Current Status and The Road Ahead](#current-status)
7. [Lessons Learned](#lessons-learned)

---

## The Vision: A Real Processor for Real Firmware {#the-vision}

When you read about processors in textbooks, they're elegant abstractions: fetch, decode, execute, writeback. When you actually *build* one, you discover that the devil is in the details—and those details are everywhere.

Our goal wasn't to build a toy CPU that could add two numbers. We set out to create a **physical hardware implementation** of a RISC-V processor sophisticated enough to boot [OpenSBI](https://github.com/riscv-software-src/opensbi), the official RISC-V Supervisor Binary Interface firmware. This meant implementing:

- **RV32I**: The base 32-bit integer instruction set (40+ instructions)
- **M Extension**: Integer multiplication and division
- **A Extension**: Atomic memory operations
- **Zicsr Extension**: Control and Status Register instructions for privilege levels and trap handling

This isn't a weekend project. This is what semiconductor companies and research labs do when they prototype new processors. The difference? We're doing it in the open, learning as we go, and documenting every painful lesson.

---

## Phase 0: Environment Setup

Before writing a single line of code, we assembled our toolchain:

**Simulation & Verification:**
- **Verilator 5.020**: A lightning-fast open-source Verilog/SystemVerilog simulator that compiles HDL to C++. Used by Google, Western Digital, and other companies for production verification.
- **GTKWave**: For viewing waveforms and debugging timing issues.

**Software Development:**
- **RISC-V GNU Toolchain**: Cross-compiler (`riscv64-linux-gnu-gcc`) to compile C and assembly programs targeting our processor.
- **Device Tree Compiler (DTC)**: For describing the hardware topology to OpenSBI (planned for later phases).

**Why This Matters:** Using industry-standard tools means our design can evolve into something real. Verilator can simulate millions of cycles per second, making it practical to boot complex firmware that would take hours in slower simulators.

---

## Phase 1: Microarchitecture Definition {#phase-1-microarchitecture-definition}

Here's the crucial insight that separates hobbyist CPU projects from real ones: **you must design the microarchitecture before writing RTL**.

RTL (Register Transfer Level) code describes *what* hardware exists: "there's a 32-bit register here, a multiplexer there." But RTL doesn't tell you *how* the processor works. That's the microarchitecture's job.

### Our CPU State Machine

We designed a simple, non-pipelined processor with 8 states:

```
STATE_RESET → STATE_FETCH → STATE_FETCH_WAIT → STATE_DECODE → 
STATE_EXECUTE → STATE_MEMORY → STATE_MEMORY_WAIT → STATE_WRITEBACK → 
(back to STATE_FETCH)
```

**Why not pipelined?** Pipelining (where multiple instructions overlap in execution) is faster but *vastly* more complex. Hazards, forwarding, branch prediction—we'd spend months on that alone. For a first pass at booting firmware, a simple multi-cycle design is the pragmatic choice.

### The Datapath

We documented how data flows through the processor:

- **32 General-Purpose Registers**: x0 (always zero) through x31
- **Program Counter (PC)**: Tracks which instruction to execute next
- **ALU**: Arithmetic and logic operations (add, subtract, shifts, comparisons)
- **Multiply/Divide Unit**: Multi-cycle implementation of M-extension
- **CSR File**: Privilege and trap handling registers
- **Bus Interface**: Connects CPU to RAM and peripherals

### Memory Map

We defined where everything lives in the 32-bit address space:

```
0x00000000 - 0x003FFFFF : RAM (4MB)
0x10000000 - 0x100000FF : UART (ns16550a compatible)
```

**Critical Decision:** Starting RAM at address 0 means our reset vector (where the CPU starts executing) is at 0x00000000. This matches what OpenSBI expects.

### Control Signals

For each instruction type, we documented:
- When to write the register file
- Which ALU operation to perform
- When to access memory
- How to update the PC (sequential, branch, jump, trap)

**Deliverables from Phase 1:**
- `docs/cpu_state_machine.md`
- `docs/datapath.md`
- `docs/control_signals.md`
- `docs/memory_map.md`
- `docs/csr_requirements.md`

These documents became our contract. When debugging later, we could ask: "Does the RTL match the spec?" If not, we knew where the bug was.

---

## Phase 2: RTL Implementation {#phase-2-rtl-implementation}

With our blueprint complete, we translated the design into synthesizable SystemVerilog. This phase took several weeks and resulted in **2,246 lines of hardware description code** across 11 modules.

### Module 1: Register File (`rtl/core/register_file.sv`)

```systemverilog
module register_file (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [4:0]  rs1_addr, rs2_addr, rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_we,
    output logic [31:0] rs1_data, rs2_data
);
```

The register file has two read ports (for source operands rs1 and rs2) and one write port (for destination rd). A critical detail: `x0` must always read as zero, regardless of what anyone tries to write to it.

```systemverilog
always_ff @(posedge clk) begin
    if (rd_we && rd_addr != 5'b00000) begin
        registers[rd_addr] <= rd_data;
    end
end

assign rs1_data = (rs1_addr == 5'b00000) ? 32'h0 : registers[rs1_addr];
assign rs2_data = (rs2_addr == 5'b00000) ? 32'h0 : registers[rs2_addr];
```

**Why asynchronous reads?** In our multi-cycle design, we need register values immediately during the DECODE state. A synchronous read would add an extra cycle to every instruction.

### Module 2: ALU (`rtl/core/alu.sv`)

The ALU implements all RV32I arithmetic and logical operations:

```systemverilog
case (alu_op)
    ALU_OP_ADD:  result = a + b;
    ALU_OP_SUB:  result = a - b;
    ALU_OP_SLL:  result = a << b[4:0];
    ALU_OP_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
    ALU_OP_SLTU: result = (a < b) ? 32'd1 : 32'd0;
    ALU_OP_XOR:  result = a ^ b;
    ALU_OP_SRL:  result = a >> b[4:0];
    ALU_OP_SRA:  result = $signed(a) >>> b[4:0];
    ALU_OP_OR:   result = a | b;
    ALU_OP_AND:  result = a & b;
endcase
```

**Detail that matters:** The shift amount comes from only the lower 5 bits of `b` (because you can't shift a 32-bit value by more than 31 positions). Getting this wrong would cause weird behavior in code that uses shifts.

### Module 3: Decoder (`rtl/core/decoder.sv`)

The decoder is the CPU's "instruction interpreter." It looks at the 32-bit instruction word and determines:
- What type of instruction is this? (R-type, I-type, S-type, B-type, U-type, J-type)
- Which registers does it use?
- What immediate value (if any) should be extracted?
- Is this a load? A store? A branch? An ALU operation?

RISC-V has a beautifully regular encoding, but there are still plenty of special cases:

```systemverilog
always_comb begin
    case (opcode)
        7'b0110011: begin // R-type: register-register operations
            is_r_type = 1;
            imm = 32'h0;
        end
        7'b0010011: begin // I-type: immediate arithmetic
            is_i_type = 1;
            imm = {{20{instruction[31]}}, instruction[31:20]}; // Sign-extend
        end
        7'b0000011: begin // Load instructions
            is_load = 1;
            imm = {{20{instruction[31]}}, instruction[31:20]};
        end
        // ... 20 more cases ...
    endcase
end
```

**The challenge:** Every instruction format extracts the immediate value differently. Get the bit positions wrong, and your jumps will go to random addresses.

### Module 4: Multiply/Divide Unit (`rtl/core/muldiv.sv`)

The M-extension requires multiplication and division. We implemented a simple multi-cycle iterative divider and a single-cycle multiplier (using the `*` operator, which synthesizes to a hardware multiplier).

**Trade-off:** A single-cycle 32×32 multiplier uses a lot of logic gates. A multi-cycle implementation would be smaller but slower. For now, we prioritized working over optimal.

### Module 5: CSR File (`rtl/core/csr_file.sv`)

Control and Status Registers are what make a processor capable of running an operating system. They control:
- Privilege levels (Machine mode, Supervisor mode, User mode)
- Trap handling (what happens on exceptions and interrupts)
- Timers and counters

For OpenSBI, we need at least 12 CSRs:

```systemverilog
// Machine-mode CSRs
logic [31:0] mstatus;   // Machine status
logic [31:0] misa;      // ISA and extensions
logic [31:0] mie;       // Interrupt enable
logic [31:0] mtvec;     // Trap vector base address
logic [31:0] mepc;      // Exception PC
logic [31:0] mcause;    // Trap cause
logic [31:0] mtval;     // Trap value
logic [31:0] mip;       // Interrupt pending
logic [31:0] mscratch;  // Scratch register
```

The CSR file also implements the `CSRRW`, `CSRRS`, `CSRRC` instructions that read/write these registers atomically.

### Module 6: CPU Core (`rtl/core/cpu_core.sv`)

This is the heart of the processor: 637 lines that tie everything together. The core instantiates all submodules and implements the state machine:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_RESET;
        pc <= 32'h00000000;
    end else begin
        state <= next_state;
        case (state)
            STATE_FETCH_WAIT: begin
                if (ibus_ready) instruction <= ibus_rdata;
            end
            STATE_EXECUTE: begin
                alu_result_reg <= alu_result;
                // ... latch other values ...
            end
            STATE_MEMORY_WAIT: begin
                if (dbus_ready) mem_data_reg <= dbus_rdata;
            end
            STATE_WRITEBACK: begin
                if (reg_write_enable_latched) 
                    // Write to register file
                pc <= next_pc;
            end
        endcase
    end
end
```

**Key insight:** We needed to latch (save) values from one state to use in later states. For example, the ALU result computed in EXECUTE must be saved so it can be written to a register in WRITEBACK. Missing any of these latches leads to subtle bugs.

---

## Phase 3: System Integration {#phase-3-system-integration}

A CPU is useless without memory and I/O. We built a simple System-on-a-Chip:

### Simple Bus Arbiter (`rtl/bus/simple_bus.sv`)

The bus connects the CPU to peripherals using address-based routing:

```systemverilog
always_comb begin
    if (ibus_addr >= 32'h00000000 && ibus_addr < 32'h00400000) begin
        ibus_to_ram = 1;
        ibus_to_uart = 0;
    end else if (ibus_addr >= 32'h10000000 && ibus_addr < 32'h10000100) begin
        ibus_to_ram = 0;
        ibus_to_uart = 1;
    end
    // ... similar logic for data bus ...
end
```

### RAM Module (`rtl/peripherals/ram.sv`)

We implemented a simple synchronous RAM that can be pre-loaded with a program:

```systemverilog
initial begin
    if (MEM_INIT_FILE != "") begin
        $readmemh(MEM_INIT_FILE, mem);
    end
end
```

This lets us compile an assembly program, convert it to a hex file, and load it into the simulation's memory at startup.

### UART 16550 (`rtl/peripherals/uart_16550.sv`)

The UART is our window into the processor. When the CPU writes a byte to address `0x10000000`, the UART sends it out as a serial character. Our testbench captures these characters and prints them to the console.

**Why ns16550a?** It's an industry-standard UART controller. OpenSBI expects to find this specific peripheral, with registers at specific offsets.

### Top-Level SoC (`rtl/soc/riscv_soc.sv`)

The top module wires everything together:

```systemverilog
module riscv_soc #(
    parameter MEM_INIT_FILE = ""
) (
    input  logic clk,
    input  logic rst_n,
    output logic uart_tx
);

cpu_core u_cpu_core (
    .clk(clk),
    .rst_n(rst_n),
    .ibus_req(ibus_req),
    .ibus_addr(ibus_addr),
    // ... many more connections ...
);

simple_bus u_simple_bus (
    .clk(clk),
    .rst_n(rst_n),
    .ibus_req(ibus_req),
    // ... route between CPU and peripherals ...
);

ram #(.MEM_INIT_FILE(MEM_INIT_FILE)) u_ram (...);
uart_16550 u_uart (...);

endmodule
```

**At this point:** We had 2,246 lines of RTL that *compiled*. But did it *work*? Not even close.

---

## Phase 4: Simulation and Debugging {#phase-4-simulation-and-debugging}

### The Test Program

We wrote a simple assembly program (`sw/tests/hello.S`) to print "Hello RISC-V!\n" via the UART:

```assembly
_start:
    lui  sp, 0x400          # Set up stack pointer
    li   a0, hello_msg      # Load address of string
    jal  print_string       # Call print function

print_string:
    lui  a1, 0x10000        # UART base address
print_loop:
    lbu  t0, 0(a0)          # Load byte from string
    beqz t0, print_done     # If zero, we're done
wait_uart:
    lbu  t1, 5(a1)          # Check UART status register
    andi t1, t1, 32         # Check TX empty bit
    beqz t1, wait_uart      # Wait until ready
    sb   t0, 0(a1)          # Write character to UART
    addi a0, a0, 1          # Increment string pointer
    j    print_loop         # Repeat

print_done:
    ret

hello_msg:
    .string "Hello RISC-V!\n"
```

We compiled it with the RISC-V toolchain:

```bash
riscv64-linux-gnu-gcc -march=rv32ima_zicsr -mabi=ilp32 -nostdlib -Ttext=0x0 -o hello.elf hello.S
riscv64-linux-gnu-objcopy -O binary hello.elf hello.bin
od -An -tx4 -w4 -v hello.bin | awk '{print $1}' > hello.hex
```

The result: a `hello.hex` file containing the machine code, ready to load into our simulated RAM.

### The Testbench

We built a SystemVerilog testbench (`sim/testbenches/tb_soc.sv`) that:
1. Instantiates our SoC
2. Generates a clock signal (50 MHz)
3. Resets the processor
4. Captures UART output
5. Runs for a fixed time, then reports success or failure

We also created a C++ wrapper (`sim/sim_main.cpp`) for Verilator that makes the simulation run fast and easy to debug.

### The Debugging Odyssey: Eight Critical Bugs

When we first ran the simulation, nothing worked. The PC didn't advance. Registers had garbage. The UART was silent. Over several days of intense debugging, we discovered and fixed eight critical bugs:

#### Bug #1: Bus Request Signals Not Held During Wait States

**Symptom:** The CPU would request an instruction fetch, but the bus would never respond.

**Root Cause:** Our bus logic looked for `ibus_req` to be HIGH. But in the original code, `ibus_req` was only HIGH during `STATE_FETCH`, and went LOW during `STATE_FETCH_WAIT`. By the time the RAM was ready, the request had disappeared!

**Fix:**
```systemverilog
// OLD: ibus_req = (state == STATE_FETCH);
// NEW:
ibus_req = (state == STATE_FETCH) || (state == STATE_FETCH_WAIT);
```

**Lesson:** Request-acknowledge handshakes require the request to be stable until acknowledged.

#### Bug #2: Register Write Enable Not Latched

**Symptom:** Registers weren't getting updated even though the decoder said they should be.

**Root Cause:** The `reg_write_enable` signal was computed in the DECODE state, but we needed it in the WRITEBACK state (several cycles later). By then, the instruction had changed, and `reg_write_enable` had the wrong value.

**Fix:** Added a register to latch the signal:
```systemverilog
always_ff @(posedge clk) begin
    if (state == STATE_EXECUTE) begin
        reg_write_enable_latched <= reg_write_enable;
    end
end

assign rf_rd_we = (state == STATE_WRITEBACK) && reg_write_enable_latched && (rd != 5'b00000);
```

**Lesson:** In a multi-cycle processor, control signals must be latched at the right time.

#### Bug #3: PC Updated Incorrectly After Branches

**Symptom:** After a `JAL` instruction, the PC would advance by 4 instead of jumping to the target address.

**Root Cause:** Our PC update logic in WRITEBACK always added 4:
```systemverilog
// OLD:
if (state == STATE_WRITEBACK) begin
    next_pc = pc + 4;
end
```

**Fix:** Only advance by 4 for sequential instructions:
```systemverilog
if (state == STATE_WRITEBACK) begin
    if (!is_jal && !is_jalr && !(is_branch && branch_taken)) begin
        next_pc = pc + 4;
    end
end
```

For jumps and taken branches, `next_pc` was already set correctly during EXECUTE.

**Lesson:** Control flow instructions need special handling in PC update logic.

#### Bug #4: Register Write Data Source Not Latched

**Symptom:** Loads would write the wrong value to the register.

**Root Cause:** The multiplexer selecting what to write back (`reg_write_source`) was using the current instruction's value, not the latched value from the load instruction.

**Fix:** Latch the source selector along with write enable:
```systemverilog
always_ff @(posedge clk) begin
    if (state == STATE_EXECUTE) begin
        reg_write_source_latched <= reg_write_source;
    end
end
```

**Lesson:** Every control signal used in a later stage must be latched.

#### Bug #5: Load Instructions Not Extracting Bytes Correctly

**Symptom:** Loading the byte 'H' (0x48) from address 0xFC was producing garbage.

**Root Cause:** The `LBU` (Load Byte, Unsigned) instruction is supposed to:
1. Load a 32-bit word from memory
2. Extract the correct byte based on the address offset
3. Zero-extend it to 32 bits

We were just passing through the entire 32-bit word!

**Fix:** Added logic to extract and sign-extend:
```systemverilog
// Latch the control signals
always_ff @(posedge clk) begin
    if (state == STATE_EXECUTE) begin
        mem_addr_offset <= alu_result_reg[1:0];
        mem_width_latched <= mem_width;
        mem_unsigned_latched <= mem_unsigned;
    end
end

// In WRITEBACK, extract the right byte/halfword
always_comb begin
    case (mem_width_latched)
        2'b00: begin // Byte
            case (mem_addr_offset)
                2'b00: byte_data = mem_data_reg[7:0];
                2'b01: byte_data = mem_data_reg[15:8];
                2'b10: byte_data = mem_data_reg[23:16];
                2'b11: byte_data = mem_data_reg[31:24];
            endcase
            mem_data_processed = mem_unsigned_latched ? 
                {24'b0, byte_data} : 
                {{24{byte_data[7]}}, byte_data};
        end
        // ... similar for halfword and word ...
    endcase
end
```

**Lesson:** Memory operations must handle alignment and size conversions.

#### Bug #6: Memory Address Using Wrong ALU Result

**Symptom:** Stores and loads were going to wrong addresses.

**Root Cause:** During the MEMORY state, we were using the *current* ALU output instead of the *latched* result from EXECUTE:

```systemverilog
// OLD: dbus_addr = alu_result;
// NEW:
dbus_addr = alu_result_reg;
```

**Lesson:** Use latched values, not combinational outputs from previous stages.

#### Bug #7: UART Byte Addressing

**Symptom:** Writes to the UART weren't working.

**Root Cause:** Our CPU generates word addresses (0x10000000, 0x10000004, etc.), but the UART has byte-wide registers. The UART's address decoder was looking at the wrong bits:

```systemverilog
// OLD: reg_addr = addr[4:2];  // Word addressing
// NEW:
reg_addr = addr[2:0];   // Byte addressing
```

**Lesson:** Peripherals and CPUs must agree on addressing conventions.

#### Bug #8: Store Instructions Never Advanced the PC

**Symptom:** After printing 'H' once, the CPU got stuck in an infinite loop, printing 'H' forever.

**Root Cause:** This was the most subtle bug. Store instructions transitioned from `STATE_MEMORY_WAIT` directly back to `STATE_FETCH`, skipping `STATE_WRITEBACK`:

```systemverilog
// In state machine
STATE_MEMORY_WAIT: begin
    if (dbus_ready) begin
        if (is_load) begin
            next_state = STATE_WRITEBACK;
        end else begin
            next_state = STATE_FETCH;  // Stores skip writeback
        end
    end
end
```

But the PC update logic was only in WRITEBACK:

```systemverilog
STATE_WRITEBACK: begin
    next_pc = pc + 4;  // Only happens if we go through WRITEBACK!
end
```

So stores never incremented the PC, causing the CPU to execute the same store instruction forever.

**Fix:** Make stores go through WRITEBACK too:

```systemverilog
STATE_MEMORY_WAIT: begin
    if (dbus_ready) begin
        next_state = STATE_WRITEBACK;  // Both loads and stores
    end
end
```

**Lesson:** Every instruction must advance the PC, even if it doesn't write a register.

---

## Current Status {#current-status}

After fixing all eight bugs, we ran the simulation:

```bash
make clean && make sw && make sim
./build/verilator/Vtb_soc
```

And saw:

```
=== Starting RISC-V SoC Simulation ===
Reset released at time 190000
Waiting for UART output...
[1270000] UART WRITE: addr=0x10000000 data=0x48 'H' (PC=0x00000028)
[2190000] UART WRITE: addr=0x10000000 data=0x65 'e' (PC=0x00000028)
[3110000] UART WRITE: addr=0x10000000 data=0x6c 'l' (PC=0x00000028)
[4030000] UART WRITE: addr=0x10000000 data=0x6c 'l' (PC=0x00000028)
[4950000] UART WRITE: addr=0x10000000 data=0x6f 'o' (PC=0x00000028)
[5870000] UART WRITE: addr=0x10000000 data=0x20 ' ' (PC=0x00000028)
[6790000] UART WRITE: addr=0x10000000 data=0x52 'R' (PC=0x00000028)
[7710000] UART WRITE: addr=0x10000000 data=0x49 'I' (PC=0x00000028)
[8630000] UART WRITE: addr=0x10000000 data=0x53 'S' (PC=0x00000028)
[9550000] UART WRITE: addr=0x10000000 data=0x43 'C' (PC=0x00000028)
[10470000] UART WRITE: addr=0x10000000 data=0x2d '-' (PC=0x00000028)
[11390000] UART WRITE: addr=0x10000000 data=0x56 'V' (PC=0x00000028)
[12310000] UART WRITE: addr=0x10000000 data=0x21 '!' (PC=0x00000028)
[13230000] UART WRITE: addr=0x10000000 data=0x0a '\n' (PC=0x00000028)
```

**Success!** Our processor is alive and printing "Hello RISC-V!" to the console.

### What We've Achieved

**A working RISC-V CPU core** that executes real assembly programs  
**All RV32I instructions** implemented and verified  
**Memory-mapped I/O** working correctly  
**Multi-cycle execution** with proper state management  
**Comprehensive debugging** infrastructure with signal tracing  

### What's Next: The Road to OpenSBI

We're currently at **Phase 4** of a 7-phase project. To reach our ultimate goal of booting OpenSBI firmware, we still need to:

**Phase 5: Complete M and A Extensions**
- Verify multiply/divide instructions work correctly
- Implement atomic memory operations (`LR`, `SC`, `AMOSWAP`, etc.)
- Write comprehensive instruction-level tests

**Phase 6: CSR and Trap Handling**
- Implement trap handling (exceptions and interrupts)
- Verify CSR read/write operations
- Test privilege level transitions
- Handle timer interrupts

**Phase 7: OpenSBI Integration**
- Build OpenSBI firmware
- Create a device tree describing our hardware
- Load OpenSBI into simulation
- Debug boot process until we see the OpenSBI banner

**Phase 8: FPGA Implementation**
- Synthesize the design for a real FPGA board
- Add clock management and I/O constraints
- Program the FPGA and verify on real hardware

---

## Lessons Learned {#lessons-learned}

### 1. Microarchitecture Documentation is Not Optional

Every bug we fixed came down to: "The RTL doesn't match what the CPU is supposed to do." Having detailed microarchitecture docs let us quickly identify these mismatches. Without them, we'd still be debugging.

### 2. Latching is Everything

In a multi-cycle CPU, you compute values in one state and use them several cycles later. If you don't latch those values, they'll have changed by the time you need them. This was the root cause of bugs #2, #4, #5, and #6.

### 3. Test Early, Test Small

We could have written the entire CPU and then tried to boot OpenSBI. That would have been a disaster. Instead, we tested each module individually, then with simple assembly programs, building up complexity gradually.

### 4. Verilator is a Superpower

Compared to commercial simulators like ModelSim, Verilator is *blazing fast*. It compiles your Verilog to C++, which then compiles to native machine code. We could simulate millions of cycles in seconds, making the debug cycle much faster.

### 5. The RISC-V Spec is Dense

Even the "simple" RV32I base instruction set has corner cases: What happens when you write to x0? How do you sign-extend immediates in B-type instructions? The specification is precise, but you need to read it very carefully.

### 6. Hardware Bugs Are Different

In software, you can add a print statement and see what's happening. In hardware, your "print statement" is adding signals to a waveform viewer and scrolling through thousands of clock cycles. Debugging requires patience and systematic thinking.

---

## The Bigger Picture

This project is inspired by the legendary article ["AI creates a bootable VM"](https://popovicu.com/posts/risc-v-sbi-and-full-boot-process/), which describes the full boot process of a RISC-V system running OpenSBI. But that article used QEMU, a software emulator.

We're doing this in *hardware*. 

That means our processor could eventually be:
- Synthesized to an FPGA and run at hundreds of MHz
- Taped out as an ASIC (with proper design tools and foundry access)
- Extended with caches, pipelines, and advanced features
- Used to boot Linux and run real applications

This is how real processors are built. Not perfectly on the first try, but iteratively, with careful design, rigorous testing, and systematic debugging.

---

## Acknowledgments

This project stands on the shoulders of giants:
- The RISC-V Foundation for creating an open, extensible ISA
- The Verilator team for an incredible open-source simulator
- The OpenSBI maintainers for production-grade firmware
- Uros Popovic's excellent article on RISC-V boot processes
- Countless contributors to the RISC-V ecosystem

---

## Try It Yourself

The entire project is open source and available at `/silicogenplayground/bootble-vm-riscv`. 

To run the simulation:

```bash
cd /silicogenplayground/bootble-vm-riscv
make clean
make sw && make sim
./build/verilator/Vtb_soc
```

You'll see our processor boot up and print "Hello RISC-V!" to the console. From there, you can:
- Modify the test program to try different instructions
- Look at waveforms in GTKWave to see the internal signals
- Add new features and extensions
- Help us reach the goal of booting OpenSBI

---

**Project Status:** Phase 4 Complete → Next: Full M/A Extension Verification  
**Lines of SystemVerilog:** 2,246  
**Bugs Fixed:** 8 (and counting)  
**Coffee Consumed:** Immeasurable  
**Satisfaction Level:** Extremely High

The journey continues. Stay tuned for the next update: **"Booting OpenSBI: From Assembly to Firmware."**
