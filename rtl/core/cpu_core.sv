// cpu_core.sv
// RISC-V RV32IMAZicsr CPU Core
// Non-pipelined implementation
// State machine: RESET -> FETCH -> FETCH_WAIT -> DECODE -> EXECUTE -> 
//                MEMORY -> MEMORY_WAIT -> WRITEBACK -> TRAP

module cpu_core (
    input  logic        clk,
    input  logic        rst_n,
    
    // Instruction bus interface
    output logic        ibus_req,
    output logic [31:0] ibus_addr,
    input  logic [31:0] ibus_rdata,
    input  logic        ibus_ready,
    input  logic        ibus_error,
    
    // Data bus interface
    output logic        dbus_req,
    output logic        dbus_we,
    output logic [31:0] dbus_addr,
    output logic [31:0] dbus_wdata,
    output logic [3:0]  dbus_wstrb,
    input  logic [31:0] dbus_rdata,
    input  logic        dbus_ready,
    input  logic        dbus_error
);

    // Import common definitions
    `include "riscv_defines.vh"
    
    // State machine
    typedef enum logic [3:0] {
        STATE_RESET,
        STATE_FETCH,
        STATE_FETCH_WAIT,
        STATE_DECODE,
        STATE_EXECUTE,
        STATE_MEMORY,
        STATE_MEMORY_WAIT,
        STATE_WRITEBACK,
        STATE_TRAP
    } state_t;
    
    state_t state, next_state;
    
    // Program Counter
    logic [31:0] pc, next_pc;
    
    // Instruction Register
    logic [31:0] instruction;
    
    // Decoded instruction fields (from decoder)
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm;
    
    // Instruction categories
    logic is_load, is_store, is_branch, is_jal, is_jalr;
    logic is_lui, is_auipc, is_alu_reg, is_alu_imm;
    logic is_system, is_mul, is_div;
    logic illegal_instruction;
    
    // Register file interface
    logic [4:0]  rf_rs1_addr, rf_rs2_addr, rf_rd_addr;
    logic [31:0] rf_rs1_data, rf_rs2_data, rf_rd_data;
    logic        rf_rd_we;
    
    // ALU interface
    logic [31:0] alu_operand_a, alu_operand_b;
    logic [3:0]  alu_op;
    logic [31:0] alu_result;
    logic        alu_zero, alu_negative;
    
    // Multiplier/Divider interface
    logic [31:0] muldiv_operand_a, muldiv_operand_b;
    logic [2:0]  muldiv_op;
    logic        muldiv_start;
    logic [31:0] muldiv_result;
    logic        muldiv_done, muldiv_busy;
    
    // CSR interface
    logic [11:0] csr_addr;
    logic [31:0] csr_wdata, csr_rdata;
    logic [1:0]  csr_op;
    logic        csr_we, csr_illegal;
    logic        trap_taken;
    logic        trap_detected;  // Combinational signal that detects trap condition
    logic [31:0] trap_pc, trap_value;
    logic [3:0]  trap_cause;
    logic        is_interrupt;
    logic        mret;
    logic [31:0] mtvec_base, mepc_out;
    
    // Control signals
    logic [1:0] pc_source;
    logic       reg_write_enable;
    logic       reg_write_enable_latched;  // Latched version for WRITEBACK
    logic [2:0] reg_write_source;
    logic [2:0] reg_write_source_latched;  // Latched version for WRITEBACK
    logic [1:0] alu_src_a, alu_src_b;
    logic       mem_read, mem_write;
    logic [1:0] mem_width;
    logic       mem_unsigned;
    logic       branch_taken;
    logic       branch_taken_latched;  // Latched version for WRITEBACK
    
    // Working registers
    logic [31:0] alu_result_reg;
    logic [31:0] mem_data_reg;
    logic [31:0] mem_data_processed;  // Processed load data (byte/halfword extracted)
    logic [31:0] pc_plus_4;
    logic [1:0]  mem_addr_offset;     // Latched address offset for byte/halfword loads
    logic [1:0]  mem_width_latched;
    logic        mem_unsigned_latched;
    
    // =======================
    // Module Instantiations
    // =======================
    
    register_file u_register_file (
        .clk            (clk),
        .rst_n          (rst_n),
        .rs1_addr       (rf_rs1_addr),
        .rs1_data       (rf_rs1_data),
        .rs2_addr       (rf_rs2_addr),
        .rs2_data       (rf_rs2_data),
        .rd_addr        (rf_rd_addr),
        .rd_data        (rf_rd_data),
        .rd_write_enable(rf_rd_we)
    );
    
    alu u_alu (
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .alu_op      (alu_op),
        .alu_result  (alu_result),
        .alu_zero    (alu_zero),
        .alu_negative(alu_negative)
    );
    
    muldiv u_muldiv (
        .clk       (clk),
        .rst_n     (rst_n),
        .operand_a (muldiv_operand_a),
        .operand_b (muldiv_operand_b),
        .muldiv_op (muldiv_op),
        .start     (muldiv_start),
        .result    (muldiv_result),
        .done      (muldiv_done),
        .busy      (muldiv_busy)
    );
    
    decoder u_decoder (
        .instruction         (instruction),
        .opcode              (opcode),
        .rd                  (rd),
        .funct3              (funct3),
        .rs1                 (rs1),
        .rs2                 (rs2),
        .funct7              (funct7),
        .imm                 (imm),
        .is_r_type           (),
        .is_i_type           (),
        .is_s_type           (),
        .is_b_type           (),
        .is_u_type           (),
        .is_j_type           (),
        .is_load             (is_load),
        .is_store            (is_store),
        .is_branch           (is_branch),
        .is_jal              (is_jal),
        .is_jalr             (is_jalr),
        .is_lui              (is_lui),
        .is_auipc            (is_auipc),
        .is_alu_reg          (is_alu_reg),
        .is_alu_imm          (is_alu_imm),
        .is_system           (is_system),
        .is_fence            (),
        .is_mul              (is_mul),
        .is_div              (is_div),
        .is_atomic           (),
        .illegal_instruction (illegal_instruction)
    );
    
    csr_file u_csr_file (
        .clk               (clk),
        .rst_n             (rst_n),
        .csr_addr          (csr_addr),
        .csr_wdata         (csr_wdata),
        .csr_op            (csr_op),
        .csr_we            (csr_we),
        .csr_rdata         (csr_rdata),
        .csr_illegal       (csr_illegal),
        .trap_taken        (trap_taken),
        .trap_pc           (trap_pc),
        .trap_cause        (trap_cause),
        .trap_value        (trap_value),
        .is_interrupt      (is_interrupt),
        .mret              (mret),
        .mtvec_base        (mtvec_base),
        .mepc_out          (mepc_out),
        .count_cycle       (1'b1),  // Always count cycles
        .count_instret     (state == STATE_WRITEBACK)
    );
    
    // =======================
    // State Machine
    // =======================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_RESET;
            trap_taken <= 1'b0;
        end else begin
            state <= next_state;
            // Pulse trap_taken high for one cycle when entering STATE_TRAP
            trap_taken <= (next_state == STATE_TRAP && state != STATE_TRAP);
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            STATE_RESET: begin
                next_state = STATE_FETCH;
            end
            
            STATE_FETCH: begin
                next_state = STATE_FETCH_WAIT;
            end
            
            STATE_FETCH_WAIT: begin
                if (ibus_ready) begin
                    if (ibus_error) begin
                        next_state = STATE_TRAP;
                    end else begin
                        next_state = STATE_DECODE;
                    end
                end
            end
            
            STATE_DECODE: begin
                if (illegal_instruction) begin
                    next_state = STATE_TRAP;
                end else begin
                    next_state = STATE_EXECUTE;
                end
            end
            
            STATE_EXECUTE: begin
                // Check for traps first (highest priority)
                if (trap_detected) begin
                    next_state = STATE_TRAP;
                end else if (is_load || is_store) begin
                    next_state = STATE_MEMORY;
                end else if (is_mul || is_div) begin
                    // Wait for mul/div to complete
                    if (muldiv_done) begin
                        next_state = STATE_WRITEBACK;
                    end
                end else begin
                    next_state = STATE_WRITEBACK;
                end
            end
            
            STATE_MEMORY: begin
                next_state = STATE_MEMORY_WAIT;
            end
            
            STATE_MEMORY_WAIT: begin
                if (dbus_ready) begin
                    if (dbus_error) begin
                        next_state = STATE_TRAP;
                    end else if (is_load) begin
                        next_state = STATE_WRITEBACK;
                    end else begin
                        next_state = STATE_WRITEBACK;  // Stores need writeback for PC update
                    end
                end
            end
            
            STATE_WRITEBACK: begin
                next_state = STATE_FETCH;
            end
            
            STATE_TRAP: begin
                next_state = STATE_FETCH;
            end
            
            default: next_state = STATE_RESET;
        endcase
    end
    
    // =======================
    // Program Counter Logic
    // =======================
    
    assign pc_plus_4 = pc + 4;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;  // Reset vector
        end else begin
            pc <= next_pc;
        end
    end
    
    // PC update logic
    always_comb begin
        next_pc = pc;  // Hold by default
        
        case (state)
            STATE_RESET: begin
                next_pc = 32'h00000000;
            end
            
            STATE_EXECUTE: begin
                if (is_branch && branch_taken) begin
                    next_pc = pc + imm;  // Branch target
                end else if (is_jal) begin
                    next_pc = pc + imm;  // JAL target
                end else if (is_jalr) begin
                    next_pc = (rf_rs1_data + imm) & ~32'h1;  // JALR target (clear LSB)
                end else if (mret) begin
                    next_pc = mepc_out;  // Return from trap
                end
            end
            
            STATE_WRITEBACK: begin
                // Only advance PC for sequential execution
                // Jumps, taken branches, and MRET already updated PC in EXECUTE
                if (!is_jal && !is_jalr && !mret && !(is_branch && branch_taken_latched)) begin
                    next_pc = pc_plus_4;  // Sequential execution
                end
            end
            
            STATE_TRAP: begin
                // Jump to trap handler
                next_pc = mtvec_base;
            end
        endcase
    end
    
    // =======================
    // Instruction Bus Control
    // =======================
    
    always_comb begin
        ibus_req = (state == STATE_FETCH) || (state == STATE_FETCH_WAIT);
        ibus_addr = pc;
    end
    
    // Latch instruction
    always_ff @(posedge clk) begin
        if (state == STATE_FETCH_WAIT && ibus_ready && !ibus_error) begin
            instruction <= ibus_rdata;
        end
    end
    
    // =======================
    // Register File Control
    // =======================
    
    assign rf_rs1_addr = rs1;
    assign rf_rs2_addr = rs2;
    assign rf_rd_addr  = rd;
    assign rf_rd_we    = (state == STATE_WRITEBACK) && reg_write_enable_latched && (rd != 5'b00000);
    
    // =======================
    // ALU Control
    // =======================
    
    // ALU operand selection
    always_comb begin
        // Operand A
        case (alu_src_a)
            2'b00: alu_operand_a = rf_rs1_data;
            2'b01: alu_operand_a = pc;
            2'b10: alu_operand_a = 32'h0;
            default: alu_operand_a = 32'h0;
        endcase
        
        // Operand B
        case (alu_src_b)
            2'b00: alu_operand_b = rf_rs2_data;
            2'b01: alu_operand_b = imm;
            2'b10: alu_operand_b = 32'h4;
            default: alu_operand_b = 32'h0;
        endcase
    end
    
    // Latch ALU result and control signals for WRITEBACK
    always_ff @(posedge clk) begin
        if (state == STATE_EXECUTE) begin
            alu_result_reg <= alu_result;
            reg_write_enable_latched <= reg_write_enable;
            reg_write_source_latched <= reg_write_source;
            branch_taken_latched <= branch_taken;  // Latch branch decision
        end
    end
    
    // =======================
    // Data Bus Control
    // =======================
    
    always_comb begin
        dbus_req = (state == STATE_MEMORY) || (state == STATE_MEMORY_WAIT);
        dbus_we = is_store;
        dbus_addr = alu_result_reg;  // Address comes from latched ALU result
        dbus_wdata = rf_rs2_data;    // Store data from rs2
        
        // Byte enable based on funct3 (mem_width)
        case (funct3[1:0])
            2'b00: dbus_wstrb = 4'b0001 << alu_result[1:0];  // Byte
            2'b01: dbus_wstrb = 4'b0011 << {alu_result[1], 1'b0};  // Half-word
            2'b10: dbus_wstrb = 4'b1111;  // Word
            default: dbus_wstrb = 4'b0000;
        endcase
    end
    
    // Latch memory control signals and address offset
    always_ff @(posedge clk) begin
        if (state == STATE_EXECUTE && (is_load || is_store)) begin
            mem_width_latched <= mem_width;
            mem_unsigned_latched <= mem_unsigned;
            mem_addr_offset <= alu_result[1:0];  // Save address offset for byte/halfword extraction
        end
    end
    
    // Latch memory data
    always_ff @(posedge clk) begin
        if (state == STATE_MEMORY_WAIT && dbus_ready && !dbus_error) begin
            mem_data_reg <= dbus_rdata;
        end
    end
    
    // Process loaded data (extract byte/halfword and sign-extend if needed)
    always_comb begin
        case (mem_width_latched)
            2'b00: begin // Byte
                case (mem_addr_offset)
                    2'b00: mem_data_processed = mem_unsigned_latched ? {24'h0, mem_data_reg[7:0]}   : {{24{mem_data_reg[7]}},  mem_data_reg[7:0]};
                    2'b01: mem_data_processed = mem_unsigned_latched ? {24'h0, mem_data_reg[15:8]}  : {{24{mem_data_reg[15]}}, mem_data_reg[15:8]};
                    2'b10: mem_data_processed = mem_unsigned_latched ? {24'h0, mem_data_reg[23:16]} : {{24{mem_data_reg[23]}}, mem_data_reg[23:16]};
                    2'b11: mem_data_processed = mem_unsigned_latched ? {24'h0, mem_data_reg[31:24]} : {{24{mem_data_reg[31]}}, mem_data_reg[31:24]};
                endcase
            end
            2'b01: begin // Halfword
                case (mem_addr_offset[1])
                    1'b0: mem_data_processed = mem_unsigned_latched ? {16'h0, mem_data_reg[15:0]}  : {{16{mem_data_reg[15]}}, mem_data_reg[15:0]};
                    1'b1: mem_data_processed = mem_unsigned_latched ? {16'h0, mem_data_reg[31:16]} : {{16{mem_data_reg[31]}}, mem_data_reg[31:16]};
                endcase
            end
            2'b10: begin // Word
                mem_data_processed = mem_data_reg;
            end
            default: mem_data_processed = mem_data_reg;
        endcase
    end
    
    // =======================
    // Writeback Data Selection
    // =======================
    
    always_comb begin
        // Use latched control signal in WRITEBACK state
        case (reg_write_source_latched)
            3'b000: rf_rd_data = alu_result_reg;      // ALU result
            3'b001: rf_rd_data = mem_data_processed;  // Load data (byte/halfword extracted and sign-extended)
            3'b010: rf_rd_data = pc_plus_4;           // JAL/JALR return address
            3'b011: rf_rd_data = csr_rdata;           // CSR read
            3'b100: rf_rd_data = muldiv_result;       // MUL/DIV result
            3'b101: rf_rd_data = imm;                 // LUI
            default: rf_rd_data = 32'h0;
        endcase
    end
    
    // =======================
    // Control Unit (Instruction Decode)
    // =======================
    
    always_comb begin
        // Default values
        pc_source = 2'b00;
        reg_write_enable = 1'b0;
        reg_write_source = 3'b000;
        alu_src_a = 2'b00;
        alu_src_b = 2'b00;
        alu_op = 4'b0000;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_width = 2'b10;
        mem_unsigned = 1'b0;
        branch_taken = 1'b0;
        muldiv_start = 1'b0;
        muldiv_op = 3'b000;
        muldiv_operand_a = rf_rs1_data;
        muldiv_operand_b = rf_rs2_data;
        csr_addr = instruction[31:20];
        csr_wdata = rf_rs1_data;
        csr_op = 2'b00;
        csr_we = 1'b0;
        mret = 1'b0;
        trap_detected = 1'b0;  // Combinational trap detection
        trap_pc = pc;
        trap_cause = 4'h0;
        trap_value = 32'h0;
        is_interrupt = 1'b0;
        
        if (state == STATE_DECODE || state == STATE_EXECUTE) begin
            // ALU Register operations (R-type)
            if (is_alu_reg) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b000;
                alu_src_a = 2'b00;  // rs1
                alu_src_b = 2'b00;  // rs2
                
                case ({funct7[5], funct3})
                    4'b0_000: alu_op = 4'b0000;  // ADD
                    4'b1_000: alu_op = 4'b0001;  // SUB
                    4'b0_001: alu_op = 4'b0101;  // SLL
                    4'b0_010: alu_op = 4'b1000;  // SLT
                    4'b0_011: alu_op = 4'b1001;  // SLTU
                    4'b0_100: alu_op = 4'b0100;  // XOR
                    4'b0_101: alu_op = 4'b0110;  // SRL
                    4'b1_101: alu_op = 4'b0111;  // SRA
                    4'b0_110: alu_op = 4'b0011;  // OR
                    4'b0_111: alu_op = 4'b0010;  // AND
                    default:  alu_op = 4'b0000;
                endcase
            end
            
            // ALU Immediate operations (I-type)
            else if (is_alu_imm) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b000;
                alu_src_a = 2'b00;  // rs1
                alu_src_b = 2'b01;  // immediate
                
                case (funct3)
                    3'b000: alu_op = 4'b0000;  // ADDI
                    3'b001: alu_op = 4'b0101;  // SLLI
                    3'b010: alu_op = 4'b1000;  // SLTI
                    3'b011: alu_op = 4'b1001;  // SLTIU
                    3'b100: alu_op = 4'b0100;  // XORI
                    3'b101: alu_op = funct7[5] ? 4'b0111 : 4'b0110;  // SRAI : SRLI
                    3'b110: alu_op = 4'b0011;  // ORI
                    3'b111: alu_op = 4'b0010;  // ANDI
                    default: alu_op = 4'b0000;
                endcase
            end
            
            // Load operations
            else if (is_load) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b001;  // Memory data
                alu_src_a = 2'b00;  // rs1
                alu_src_b = 2'b01;  // immediate
                alu_op = 4'b0000;   // ADD for address calculation
                mem_read = 1'b1;
                mem_width = funct3[1:0];
                mem_unsigned = funct3[2];
            end
            
            // Store operations
            else if (is_store) begin
                alu_src_a = 2'b00;  // rs1
                alu_src_b = 2'b01;  // immediate
                alu_op = 4'b0000;   // ADD for address calculation
                mem_write = 1'b1;
                mem_width = funct3[1:0];
            end
            
            // Branch operations
            else if (is_branch && state == STATE_EXECUTE) begin
                alu_src_a = 2'b00;  // rs1
                alu_src_b = 2'b00;  // rs2
                
                case (funct3)
                    3'b000: branch_taken = (rf_rs1_data == rf_rs2_data);  // BEQ
                    3'b001: branch_taken = (rf_rs1_data != rf_rs2_data);  // BNE
                    3'b100: branch_taken = ($signed(rf_rs1_data) < $signed(rf_rs2_data));  // BLT
                    3'b101: branch_taken = ($signed(rf_rs1_data) >= $signed(rf_rs2_data)); // BGE
                    3'b110: branch_taken = (rf_rs1_data < rf_rs2_data);  // BLTU
                    3'b111: branch_taken = (rf_rs1_data >= rf_rs2_data); // BGEU
                    default: branch_taken = 1'b0;
                endcase
            end
            
            // JAL
            else if (is_jal) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b010;  // PC + 4
            end
            
            // JALR
            else if (is_jalr) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b010;  // PC + 4
            end
            
            // LUI
            else if (is_lui) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b101;  // Immediate
            end
            
            // AUIPC
            else if (is_auipc) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b000;  // ALU result
                alu_src_a = 2'b01;  // PC
                alu_src_b = 2'b01;  // Immediate
                alu_op = 4'b0000;   // ADD
            end
            
            // MUL operations
            else if (is_mul && state == STATE_EXECUTE) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b100;  // MUL/DIV result
                muldiv_start = 1'b1;
                muldiv_op = funct3;
            end
            
            // DIV operations
            else if (is_div && state == STATE_EXECUTE) begin
                reg_write_enable = 1'b1;
                reg_write_source = 3'b100;  // MUL/DIV result
                muldiv_start = 1'b1;
                muldiv_op = funct3;
            end
            
            // System instructions (CSR, ECALL, EBREAK, MRET)
            else if (is_system) begin
                if (funct3 == 3'b000) begin
                    // ECALL/EBREAK/MRET
                    if (imm == 32'h302) begin
                        mret = 1'b1;
                    end else begin
                        trap_detected = 1'b1;
                        trap_cause = (imm == 32'h1) ? 4'h3 : 4'hB;  // EBREAK : ECALL
                    end
                end else begin
                    // CSR instructions
                    reg_write_enable = 1'b1;
                    reg_write_source = 3'b011;  // CSR data
                    csr_we = 1'b1;
                    
                    case (funct3[1:0])
                        2'b01: csr_op = 2'b01;  // CSRRW
                        2'b10: csr_op = 2'b10;  // CSRRS
                        2'b11: csr_op = 2'b11;  // CSRRC
                        default: csr_op = 2'b00;
                    endcase
                    
                    if (funct3[2]) begin
                        // Immediate mode
                        csr_wdata = {27'h0, rs1};  // Use rs1 field as immediate
                    end
                end
            end
        end
        
        // Handle illegal instruction trap
        if (state == STATE_DECODE && illegal_instruction) begin
            trap_detected = 1'b1;
            trap_cause = 4'h2;  // Illegal instruction
            trap_value = instruction;
        end
        
        // Handle instruction fetch error
        if (state == STATE_FETCH_WAIT && ibus_ready && ibus_error) begin
            trap_detected = 1'b1;
            trap_cause = 4'h1;  // Instruction access fault
            trap_value = pc;
        end
        
        // Handle data access error
        if (state == STATE_MEMORY_WAIT && dbus_ready && dbus_error) begin
            trap_detected = 1'b1;
            trap_cause = is_load ? 4'h5 : 4'h7;  // Load/Store access fault
            trap_value = dbus_addr;
        end
    end

endmodule
