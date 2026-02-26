// decoder.sv
// RISC-V Instruction Decoder
// Decodes 32-bit instruction into control signals and immediate values
// Supports RV32IMAZicsr instruction set

module decoder (
    input  logic [31:0] instruction,
    
    // Decoded instruction fields
    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic [31:0] imm,
    
    // Instruction type identification
    output logic is_r_type,
    output logic is_i_type,
    output logic is_s_type,
    output logic is_b_type,
    output logic is_u_type,
    output logic is_j_type,
    
    // Specific instruction categories
    output logic is_load,
    output logic is_store,
    output logic is_branch,
    output logic is_jal,
    output logic is_jalr,
    output logic is_lui,
    output logic is_auipc,
    output logic is_alu_reg,
    output logic is_alu_imm,
    output logic is_system,
    output logic is_fence,
    output logic is_mul,
    output logic is_div,
    output logic is_atomic,
    
    // Error detection
    output logic illegal_instruction
);

    // RISC-V Opcode definitions
    localparam logic [6:0] OP_LOAD     = 7'b0000011;
    localparam logic [6:0] OP_LOAD_FP  = 7'b0000111;
    localparam logic [6:0] OP_MISC_MEM = 7'b0001111;
    localparam logic [6:0] OP_IMM      = 7'b0010011;
    localparam logic [6:0] OP_AUIPC    = 7'b0010111;
    localparam logic [6:0] OP_IMM_32   = 7'b0011011;
    localparam logic [6:0] OP_STORE    = 7'b0100011;
    localparam logic [6:0] OP_STORE_FP = 7'b0100111;
    localparam logic [6:0] OP_AMO      = 7'b0101111;
    localparam logic [6:0] OP_REG      = 7'b0110011;
    localparam logic [6:0] OP_LUI      = 7'b0110111;
    localparam logic [6:0] OP_REG_32   = 7'b0111011;
    localparam logic [6:0] OP_MADD     = 7'b1000011;
    localparam logic [6:0] OP_MSUB     = 7'b1000111;
    localparam logic [6:0] OP_NMSUB    = 7'b1001011;
    localparam logic [6:0] OP_NMADD    = 7'b1001111;
    localparam logic [6:0] OP_FP       = 7'b1010011;
    localparam logic [6:0] OP_BRANCH   = 7'b1100011;
    localparam logic [6:0] OP_JALR     = 7'b1100111;
    localparam logic [6:0] OP_JAL      = 7'b1101111;
    localparam logic [6:0] OP_SYSTEM   = 7'b1110011;

    // Extract instruction fields
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // Immediate generation based on instruction format
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    always_comb begin
        // I-type immediate: imm[11:0] = inst[31:20]
        imm_i = {{20{instruction[31]}}, instruction[31:20]};
        
        // S-type immediate: imm[11:0] = {inst[31:25], inst[11:7]}
        imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        
        // B-type immediate: imm[12:0] = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
        imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], 
                 instruction[30:25], instruction[11:8], 1'b0};
        
        // U-type immediate: imm[31:0] = {inst[31:12], 12'b0}
        imm_u = {instruction[31:12], 12'b0};
        
        // J-type immediate: imm[20:0] = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
        imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12], 
                 instruction[20], instruction[30:21], 1'b0};
    end

    // Determine instruction format and select immediate
    always_comb begin
        // Default values
        is_r_type = 1'b0;
        is_i_type = 1'b0;
        is_s_type = 1'b0;
        is_b_type = 1'b0;
        is_u_type = 1'b0;
        is_j_type = 1'b0;
        imm = 32'h0;
        
        case (opcode)
            OP_LUI, OP_AUIPC: begin
                is_u_type = 1'b1;
                imm = imm_u;
            end
            
            OP_JAL: begin
                is_j_type = 1'b1;
                imm = imm_j;
            end
            
            OP_JALR, OP_LOAD, OP_IMM, OP_MISC_MEM, OP_SYSTEM: begin
                is_i_type = 1'b1;
                imm = imm_i;
            end
            
            OP_BRANCH: begin
                is_b_type = 1'b1;
                imm = imm_b;
            end
            
            OP_STORE: begin
                is_s_type = 1'b1;
                imm = imm_s;
            end
            
            OP_REG, OP_AMO: begin
                is_r_type = 1'b1;
                imm = 32'h0;
            end
            
            default: begin
                imm = 32'h0;
            end
        endcase
    end

    // Instruction category detection
    always_comb begin
        is_load     = (opcode == OP_LOAD);
        is_store    = (opcode == OP_STORE);
        is_branch   = (opcode == OP_BRANCH);
        is_jal      = (opcode == OP_JAL);
        is_jalr     = (opcode == OP_JALR);
        is_lui      = (opcode == OP_LUI);
        is_auipc    = (opcode == OP_AUIPC);
        is_alu_reg  = (opcode == OP_REG) && (funct7 != 7'b0000001); // Not M-extension
        is_alu_imm  = (opcode == OP_IMM);
        is_system   = (opcode == OP_SYSTEM);
        is_fence    = (opcode == OP_MISC_MEM);
        is_atomic   = (opcode == OP_AMO);
        
        // M-extension (multiply/divide)
        is_mul      = (opcode == OP_REG) && (funct7 == 7'b0000001) && 
                      (funct3 == 3'b000 || funct3 == 3'b001 || 
                       funct3 == 3'b010 || funct3 == 3'b011);
        is_div      = (opcode == OP_REG) && (funct7 == 7'b0000001) && 
                      (funct3 == 3'b100 || funct3 == 3'b101 || 
                       funct3 == 3'b110 || funct3 == 3'b111);
    end

    // Illegal instruction detection
    always_comb begin
        illegal_instruction = 1'b0;
        
        // Check for unsupported opcodes
        case (opcode)
            OP_LOAD, OP_STORE, OP_BRANCH, OP_JAL, OP_JALR,
            OP_LUI, OP_AUIPC, OP_IMM, OP_REG, OP_SYSTEM,
            OP_MISC_MEM, OP_AMO: begin
                illegal_instruction = 1'b0;
            end
            
            // Unsupported opcodes (FP, RV64, etc.)
            OP_LOAD_FP, OP_STORE_FP, OP_IMM_32, OP_REG_32,
            OP_MADD, OP_MSUB, OP_NMSUB, OP_NMADD, OP_FP: begin
                illegal_instruction = 1'b1;
            end
            
            default: begin
                illegal_instruction = 1'b1;
            end
        endcase
        
        // Check for illegal funct3/funct7 combinations
        if (opcode == OP_LOAD) begin
            // Valid load types: LB(000), LH(001), LW(010), LBU(100), LHU(101)
            if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111) begin
                illegal_instruction = 1'b1;
            end
        end
        
        if (opcode == OP_STORE) begin
            // Valid store types: SB(000), SH(001), SW(010)
            if (funct3 != 3'b000 && funct3 != 3'b001 && funct3 != 3'b010) begin
                illegal_instruction = 1'b1;
            end
        end
        
        if (opcode == OP_BRANCH) begin
            // Valid branch types: BEQ(000), BNE(001), BLT(100), BGE(101), BLTU(110), BGEU(111)
            if (funct3 == 3'b010 || funct3 == 3'b011) begin
                illegal_instruction = 1'b1;
            end
        end
        
        if (opcode == OP_REG) begin
            // Check for valid funct7 values
            // 0000000 = normal ALU, 0100000 = SUB/SRA, 0000001 = M-extension
            if (funct7 != 7'b0000000 && funct7 != 7'b0100000 && funct7 != 7'b0000001) begin
                illegal_instruction = 1'b1;
            end
        end
        
        if (opcode == OP_IMM) begin
            // For shift instructions, funct7 must be 0000000 or 0100000 (for SRAI)
            if (funct3 == 3'b001 || funct3 == 3'b101) begin
                if (funct7 != 7'b0000000 && funct7 != 7'b0100000) begin
                    illegal_instruction = 1'b1;
                end
            end
        end
        
        if (opcode == OP_SYSTEM) begin
            // Valid system instructions: ECALL, EBREAK, CSR*
            // funct3 = 000 (ECALL/EBREAK), or 001-111 (CSR instructions)
            // For ECALL/EBREAK, rs1 and rd must be 0
            if (funct3 == 3'b000) begin
                if (rs1 != 5'b00000 || rd != 5'b00000) begin
                    // Check for ECALL (imm=0) or EBREAK (imm=1) or MRET (imm=0x302)
                    if (imm_i != 32'h0 && imm_i != 32'h1 && imm_i != 32'h302) begin
                        illegal_instruction = 1'b1;
                    end
                end
            end
            // funct3 = 100 is reserved
            if (funct3 == 3'b100) begin
                illegal_instruction = 1'b1;
            end
        end
    end

endmodule
