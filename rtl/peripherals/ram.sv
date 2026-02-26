// ram.sv
// RAM controller for RISC-V SoC
// 4MB byte-addressable memory
// Supports byte, half-word, and word accesses
// Can be initialized from a hex file for simulation

module ram #(
    parameter ADDR_WIDTH = 22,  // 4MB = 2^22 bytes
    parameter DATA_WIDTH = 32,
    parameter MEM_INIT_FILE = ""
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Bus interface
    input  logic                    req,
    input  logic                    we,
    input  logic [31:0]             addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [3:0]              wstrb,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic                    ready
);

    // Memory array - 4MB organized as 1M x 32-bit words
    localparam MEM_DEPTH = 2 ** (ADDR_WIDTH - 2);  // Divide by 4 for word addressing
    logic [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Word-aligned address
    logic [ADDR_WIDTH-3:0] word_addr;
    assign word_addr = addr[ADDR_WIDTH-1:2];
    
    // Memory initialization
    initial begin
        if (MEM_INIT_FILE != "") begin
            $readmemh(MEM_INIT_FILE, memory);
        end else begin
            // Initialize to zero
            for (int i = 0; i < MEM_DEPTH; i++) begin
                memory[i] = 32'h0;
            end
        end
    end
    
    // Synchronous read/write with 1 cycle latency
    always_ff @(posedge clk) begin
        if (req) begin
            if (we) begin
                // Write operation with byte enables
                if (wstrb[0]) memory[word_addr][7:0]   <= wdata[7:0];
                if (wstrb[1]) memory[word_addr][15:8]  <= wdata[15:8];
                if (wstrb[2]) memory[word_addr][23:16] <= wdata[23:16];
                if (wstrb[3]) memory[word_addr][31:24] <= wdata[31:24];
            end
            // Read operation
            rdata <= memory[word_addr];
        end
    end
    
    // Ready signal - 1 cycle latency
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= req;
        end
    end

endmodule
