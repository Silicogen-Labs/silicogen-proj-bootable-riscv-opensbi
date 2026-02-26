// riscv_defines.vh
// Common RISC-V definitions and constants

// Opcodes (from RISC-V spec)
`define OPCODE_LOAD     7'b0000011
`define OPCODE_STORE    7'b0100011
`define OPCODE_BRANCH   7'b1100011
`define OPCODE_JALR     7'b1100111
`define OPCODE_JAL      7'b1101111
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_OP       7'b0110011
`define OPCODE_LUI      7'b0110111
`define OPCODE_AUIPC    7'b0010111
`define OPCODE_SYSTEM   7'b1110011
`define OPCODE_MISC_MEM 7'b0001111
`define OPCODE_AMO      7'b0101111

// Funct3 for branches
`define FUNCT3_BEQ   3'b000
`define FUNCT3_BNE   3'b001
`define FUNCT3_BLT   3'b100
`define FUNCT3_BGE   3'b101
`define FUNCT3_BLTU  3'b110
`define FUNCT3_BGEU  3'b111

// Funct3 for loads
`define FUNCT3_LB    3'b000
`define FUNCT3_LH    3'b001
`define FUNCT3_LW    3'b010
`define FUNCT3_LBU   3'b100
`define FUNCT3_LHU   3'b101

// Funct3 for stores
`define FUNCT3_SB    3'b000
`define FUNCT3_SH    3'b001
`define FUNCT3_SW    3'b010

// ALU operations
`define ALU_ADD   4'b0000
`define ALU_SUB   4'b0001
`define ALU_AND   4'b0010
`define ALU_OR    4'b0011
`define ALU_XOR   4'b0100
`define ALU_SLL   4'b0101
`define ALU_SRL   4'b0110
`define ALU_SRA   4'b0111
`define ALU_SLT   4'b1000
`define ALU_SLTU  4'b1001

// Exception causes (from RISC-V privileged spec)
`define CAUSE_INSN_MISALIGNED    4'h0
`define CAUSE_INSN_ACCESS_FAULT  4'h1
`define CAUSE_ILLEGAL_INSN       4'h2
`define CAUSE_BREAKPOINT         4'h3
`define CAUSE_LOAD_MISALIGNED    4'h4
`define CAUSE_LOAD_ACCESS_FAULT  4'h5
`define CAUSE_STORE_MISALIGNED   4'h6
`define CAUSE_STORE_ACCESS_FAULT 4'h7
`define CAUSE_ECALL_U            4'h8
`define CAUSE_ECALL_S            4'h9
`define CAUSE_ECALL_M            4'hB
