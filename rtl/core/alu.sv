// alu.sv
// RISC-V RV32I Arithmetic Logic Unit
// Supports all RV32I arithmetic and logical operations
// 
// Operations:
//   ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_op,
    
    output logic [31:0] alu_result,
    output logic        alu_zero,
    output logic        alu_negative
);

    // ALU operation encodings (from control_signals.md)
    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLL  = 4'b0101;
    localparam logic [3:0] ALU_SRL  = 4'b0110;
    localparam logic [3:0] ALU_SRA  = 4'b0111;
    localparam logic [3:0] ALU_SLT  = 4'b1000;
    localparam logic [3:0] ALU_SLTU = 4'b1001;
    localparam logic [3:0] ALU_PASS_A = 4'b1010;
    localparam logic [3:0] ALU_PASS_B = 4'b1011;

    // Internal signals
    logic [31:0] add_result;
    logic [31:0] sub_result;
    logic [31:0] and_result;
    logic [31:0] or_result;
    logic [31:0] xor_result;
    logic [31:0] sll_result;
    logic [31:0] srl_result;
    logic [31:0] sra_result;
    logic [31:0] slt_result;
    logic [31:0] sltu_result;
    
    // Shift amount is lower 5 bits of operand_b
    logic [4:0] shamt;
    assign shamt = operand_b[4:0];

    // Compute all operations
    always_comb begin
        add_result  = operand_a + operand_b;
        sub_result  = operand_a - operand_b;
        and_result  = operand_a & operand_b;
        or_result   = operand_a | operand_b;
        xor_result  = operand_a ^ operand_b;
        sll_result  = operand_a << shamt;
        srl_result  = operand_a >> shamt;
        sra_result  = $signed(operand_a) >>> shamt;
        
        // Set Less Than (signed comparison)
        slt_result  = ($signed(operand_a) < $signed(operand_b)) ? 32'h00000001 : 32'h00000000;
        
        // Set Less Than Unsigned
        sltu_result = (operand_a < operand_b) ? 32'h00000001 : 32'h00000000;
    end

    // Select result based on operation
    always_comb begin
        case (alu_op)
            ALU_ADD:    alu_result = add_result;
            ALU_SUB:    alu_result = sub_result;
            ALU_AND:    alu_result = and_result;
            ALU_OR:     alu_result = or_result;
            ALU_XOR:    alu_result = xor_result;
            ALU_SLL:    alu_result = sll_result;
            ALU_SRL:    alu_result = srl_result;
            ALU_SRA:    alu_result = sra_result;
            ALU_SLT:    alu_result = slt_result;
            ALU_SLTU:   alu_result = sltu_result;
            ALU_PASS_A: alu_result = operand_a;
            ALU_PASS_B: alu_result = operand_b;
            default:    alu_result = 32'h00000000;
        endcase
    end

    // Status flags
    assign alu_zero     = (alu_result == 32'h00000000);
    assign alu_negative = alu_result[31];

endmodule
