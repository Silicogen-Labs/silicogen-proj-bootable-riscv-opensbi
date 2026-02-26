### **Project Specification: Bootable VM-RISCV (Hardware Implementation)**

#### **1. Project Vision**

To create a physical hardware implementation of the RISC-V based computer system described in the "AI creates a bootable VM" article. The primary goal is to design a minimal System-on-a-Chip (SoC) capable of booting the OpenSBI firmware, moving from a software simulation to a real, working hardware prototype on an FPGA.

---

#### **2. Microarchitecture Definition**

Before RTL implementation, a simple, non-pipelained microarchitecture for the RV32IMAZicsr CPU core will be defined and documented. This document will serve as the blueprint for the SystemVerilog implementation, detailing the main states, data paths, and control signals required to execute the specified instruction sets.

---

#### **3. Core Hardware Components**

The system will be described in a Hardware Description Language (SystemVerilog) and will consist of the following memory-mapped components:

*   **CPU Core:**
    *   **Instruction Set:** RV32IMAZicsr. This is the base for our system.
        *   **RV32I:** The base 32-bit integer instruction set.
        *   **M:** Standard extension for integer multiplication and division.
        *   **A:** Standard extension for atomic instructions.
        *   **Zicsr:** Standard extension for Control and Status Register (CSR) instructions.
    *   **Functionality:** The core must be able to fetch instructions from memory, decode them, execute them, and perform load/store operations to memory.

*   **Memory (RAM):**
    *   **Type:** A single, contiguous block of on-chip or off-chip RAM.
    *   **Size:** To be determined by the target FPGA, but a minimum of **4MB** is required.
    *   **Functionality:** Must respond to read and write requests from the CPU core via the system bus.

*   **UART Peripheral (Universal Asynchronous Receiver/Transmitter):**
    *   **Compatibility:** Must be compatible with the `ns16550a` standard, as this is what OpenSBI will expect.
    *   **Functionality:** Will serve as the primary console output. When the CPU writes a character to the UART's specific memory address, that character should be sent out over a serial connection (e.g., USB-to-Serial on the FPGA board).

*   **System Bus:**
    *   **Functionality:** A simple bus fabric that connects the CPU core to the RAM and UART. It will be responsible for routing read and write requests from the CPU to the correct peripheral based on the memory address.

---

#### **4. Software & Boot Requirements**

*   **Firmware:** The hardware must be capable of running the official **OpenSBI** firmware. The specific version will be selected during development.
*   **Boot Process:** The system will start execution from a fixed reset vector (a predefined memory address). The OpenSBI binary will be pre-loaded into the system's RAM at a specific address before the system is started.
*   **Device Tree:** A Device Tree Blob (`.dtb`) will be provided to OpenSBI. This file will describe the memory map of our hardware system (e.g., "RAM is at this address and is this big," "UART is at this address").

---

#### **5. Primary Success Criterion**

The project is considered a success when:

1.  The SystemVerilog design is created for all components.
2.  The design is simulated in an RTL simulator, successfully boots the `opensbi.bin` firmware, and prints the **full OpenSBI boot log** to the simulator's console via the virtual UART.
3.  The design is synthesized, implemented on a physical FPGA board, and successfully prints the **full OpenSBI boot log** to a serial terminal on a host computer.

---

#### **6. Out of Scope for this Project**

To keep the project focused and achievable, the following features are explicitly excluded:

*   **Physical Design (ASIC Tape-out):** We are not creating a permanent chip.
*   **Advanced CPU Features:** Caches, multi-stage pipelines, Memory Management Unit (MMU), and multi-core support are not included in this initial version.
*   **Booting a Full Operating System:** The goal is to boot OpenSBI. Booting Linux would be a follow-on project that would build upon this one.
*   **Advanced Peripherals:** No graphics, networking, or storage controllers will be included.
