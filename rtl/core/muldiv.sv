// muldiv.sv
// RISC-V RV32M Extension - Multiplier and Divider
// Multi-cycle implementation
// 
// Operations:
//   MUL, MULH, MULHSU, MULHU (multiply)
//   DIV, DIVU, REM, REMU (divide/remainder)

module muldiv (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [2:0]  muldiv_op,
    input  logic        start,
    
    output logic [31:0] result,
    output logic        done,
    output logic        busy
);

    // Operation encodings
    localparam logic [2:0] OP_MUL    = 3'b000;
    localparam logic [2:0] OP_MULH   = 3'b001;
    localparam logic [2:0] OP_MULHSU = 3'b010;
    localparam logic [2:0] OP_MULHU  = 3'b011;
    localparam logic [2:0] OP_DIV    = 3'b100;
    localparam logic [2:0] OP_DIVU   = 3'b101;
    localparam logic [2:0] OP_REM    = 3'b110;
    localparam logic [2:0] OP_REMU   = 3'b111;

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        MULTIPLY,
        DIVIDE,
        DONE_STATE
    } state_t;
    
    state_t state, next_state;

    // Internal registers
    logic [2:0]  operation;
    logic [63:0] mul_result;
    logic [31:0] div_quotient;
    logic [31:0] div_remainder;
    logic [5:0]  cycle_count;
    
    // Signed operands for multiplication
    logic signed [32:0] mul_a_signed;
    logic signed [32:0] mul_b_signed;
    logic signed [65:0] mul_signed_result;
    
    // Unsigned operands for multiplication
    logic [32:0] mul_a_unsigned;
    logic [32:0] mul_b_unsigned;
    logic [65:0] mul_unsigned_result;
    
    // Division operands and results
    logic [31:0] div_a;
    logic [31:0] div_b;
    logic [63:0] div_working;
    logic        div_a_neg, div_b_neg;
    
    // FSM sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM combinational logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (muldiv_op == OP_MUL || muldiv_op == OP_MULH || 
                        muldiv_op == OP_MULHSU || muldiv_op == OP_MULHU) begin
                        next_state = MULTIPLY;
                    end else begin
                        next_state = DIVIDE;
                    end
                end
            end
            
            MULTIPLY: begin
                // Multiplication completes in 2 cycles
                if (cycle_count >= 6'd1) begin
                    next_state = DONE_STATE;
                end
            end
            
            DIVIDE: begin
                // Division takes 32 cycles
                if (cycle_count >= 6'd32) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            operation       <= 3'b000;
            mul_result      <= 64'h0;
            div_quotient    <= 32'h0;
            div_remainder   <= 32'h0;
            cycle_count     <= 6'd0;
            div_working     <= 64'h0;
            div_a           <= 32'h0;
            div_b           <= 32'h0;
            div_a_neg       <= 1'b0;
            div_b_neg       <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        operation <= muldiv_op;
                        cycle_count <= 6'd0;
                        
                        // Initialize multiplication
                        if (muldiv_op == OP_MUL || muldiv_op == OP_MULH || 
                            muldiv_op == OP_MULHSU || muldiv_op == OP_MULHU) begin
                            // Multiplication setup - store operands
                            mul_result <= 64'h0;  // Will be computed in next cycle
                        end else begin
                            // Division setup
                            case (muldiv_op)
                                OP_DIV, OP_REM: begin
                                    // Signed division
                                    div_a_neg <= operand_a[31];
                                    div_b_neg <= operand_b[31];
                                    div_a <= operand_a[31] ? (~operand_a + 1) : operand_a;
                                    div_b <= operand_b[31] ? (~operand_b + 1) : operand_b;
                                    div_working <= {32'h0, operand_a[31] ? (~operand_a + 1) : operand_a};
                                end
                                OP_DIVU, OP_REMU: begin
                                    // Unsigned division
                                    div_a_neg <= 1'b0;
                                    div_b_neg <= 1'b0;
                                    div_a <= operand_a;
                                    div_b <= operand_b;
                                    div_working <= {32'h0, operand_a};
                                end
                                default: begin
                                    div_a <= 32'h0;
                                    div_b <= 32'h1;
                                    div_a_neg <= 1'b0;
                                    div_b_neg <= 1'b0;
                                    div_working <= 64'h0;
                                end
                            endcase
                            // div_working is already set in the case above - don't overwrite!
                            div_quotient <= 32'h0;
                            div_remainder <= 32'h0;
                        end
                    end
                end
                
                MULTIPLY: begin
                    cycle_count <= cycle_count + 1;
                    
                    // Compute multiplication result based on operation type
                    if (cycle_count == 0) begin
                        case (operation)
                            OP_MUL, OP_MULH: begin
                                // Signed × Signed
                                mul_result <= $signed(operand_a) * $signed(operand_b);
                            end
                            OP_MULHSU: begin
                                // Signed × Unsigned
                                mul_result <= $signed(operand_a) * $signed({1'b0, operand_b});
                            end
                            OP_MULHU: begin
                                // Unsigned × Unsigned
                                mul_result <= operand_a * operand_b;
                            end
                            default: mul_result <= 64'h0;
                        endcase
                    end
                end
                
                DIVIDE: begin
                    cycle_count <= cycle_count + 1;
                    
                    // Non-restoring division algorithm
                    if (cycle_count < 32) begin
                        if (div_b == 32'h0) begin
                            // Division by zero
                            div_quotient <= 32'hFFFFFFFF;
                            div_remainder <= div_a;
                        end else begin
                            // Shift left by 1
                            logic [63:0] shifted;
                            shifted = {div_working[62:0], 1'b0};
                            
                            // Check if we can subtract divisor
                            if (shifted[63:32] >= div_b) begin
                                // Yes, subtract divisor from upper bits and set quotient bit
                                div_working <= {shifted[63:32] - div_b, shifted[31:0]};
                                div_quotient <= {div_quotient[30:0], 1'b1};
                            end else begin
                                // No, just shift and clear quotient bit
                                div_working <= shifted;
                                div_quotient <= {div_quotient[30:0], 1'b0};
                            end
                        end
                    end else begin
                        // Finalize: just adjust signs for signed operations, quotient is already correct
                        div_remainder <= div_working[63:32];
                        
                        // Adjust signs for signed operations
                        if (operation == OP_DIV) begin
                            if (div_a_neg ^ div_b_neg) begin
                                div_quotient <= ~div_quotient + 1;
                            end
                            if (div_a_neg) begin
                                div_remainder <= ~div_remainder + 1;
                            end
                        end else if (operation == OP_REM) begin
                            if (div_a_neg) begin
                                div_remainder <= ~div_remainder + 1;
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    // Hold result
                end
            endcase
        end
    end

    // Output logic
    always_comb begin
        busy = (state != IDLE);
        done = (state == DONE_STATE);
        
        case (operation)
            OP_MUL:    result = mul_result[31:0];
            OP_MULH:   result = mul_result[63:32];
            OP_MULHSU: result = mul_result[63:32];
            OP_MULHU:  result = mul_result[63:32];
            OP_DIV:    result = div_quotient;
            OP_DIVU:   result = div_quotient;
            OP_REM:    result = div_remainder;
            OP_REMU:   result = div_remainder;
            default:   result = 32'h0;
        endcase
    end

endmodule
