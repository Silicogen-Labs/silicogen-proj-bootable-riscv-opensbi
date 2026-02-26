// register_file.sv
// RISC-V RV32I Register File
// 32 general-purpose registers (x0-x31)
// x0 is hardwired to zero
// Dual read ports, single write port
// Synchronous write, combinational read

module register_file (
    input  logic        clk,
    input  logic        rst_n,
    
    // Read port A (rs1)
    input  logic [4:0]  rs1_addr,
    output logic [31:0] rs1_data,
    
    // Read port B (rs2)
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs2_data,
    
    // Write port
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_write_enable
);

    // Register storage: 32 registers x 32 bits
    // x0 is hardwired to zero, so we don't need to store it
    logic [31:0] registers [31:0];

    // Combinational read (asynchronous)
    // x0 always reads as zero
    always_comb begin
        rs1_data = (rs1_addr == 5'b00000) ? 32'h00000000 : registers[rs1_addr];
        rs2_data = (rs2_addr == 5'b00000) ? 32'h00000000 : registers[rs2_addr];
    end

    // Synchronous write
    // Writes to x0 are ignored
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers to zero
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'h00000000;
            end
        end else begin
            if (rd_write_enable && (rd_addr != 5'b00000)) begin
                registers[rd_addr] <= rd_data;
            end
        end
    end

    // Synthesis directives to prevent optimization of x0
    // This ensures x0 remains zero
    /* verilator lint_off UNUSED */
    logic _unused_x0 = &{1'b0, registers[0]};
    /* verilator lint_on UNUSED */

endmodule
