// RISC-V Timer Peripheral
// Implements mtime and mtimecmp registers for timer interrupts
//
// Memory Map (RISC-V standard addresses):
//   0x0200BFF8: mtime (low 32 bits)
//   0x0200BFFC: mtime (high 32 bits) 
//   0x02004000: mtimecmp (low 32 bits)
//   0x02004004: mtimecmp (high 32 bits)
//
// Interrupt Behavior:
//   - timer_irq is HIGH when mtime >= mtimecmp
//   - Writing to mtimecmp clears the interrupt
//   - mtime increments every clock cycle

module timer (
    input  logic        clk,
    input  logic        rst_n,
    
    // Memory-mapped register access
    input  logic        req,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        we,
    output logic [31:0] rdata,
    output logic        ready,
    
    // Interrupt output to CPU
    output logic        timer_irq
);

    // 64-bit timer registers
    logic [63:0] mtime;      // Current time counter
    logic [63:0] mtimecmp;   // Compare value for interrupt

    // Address decoding
    logic access_mtime_lo;
    logic access_mtime_hi;
    logic access_mtimecmp_lo;
    logic access_mtimecmp_hi;
    
    assign access_mtime_lo    = (addr == 32'h0200BFF8);
    assign access_mtime_hi    = (addr == 32'h0200BFFC);
    assign access_mtimecmp_lo = (addr == 32'h02004000);
    assign access_mtimecmp_hi = (addr == 32'h02004004);

    // Timer counter - increments every cycle
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 64'h0;
        end else begin
            mtime <= mtime + 64'h1;
        end
    end

    // mtimecmp register - writable
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF;  // Max value (no interrupt initially)
        end else if (req && we) begin
            if (access_mtimecmp_lo) begin
                mtimecmp[31:0] <= wdata;
            end else if (access_mtimecmp_hi) begin
                mtimecmp[63:32] <= wdata;
            end
        end
    end

    // Read data multiplexer
    always_comb begin
        rdata = 32'h0;
        if (req && !we) begin
            if (access_mtime_lo) begin
                rdata = mtime[31:0];
            end else if (access_mtime_hi) begin
                rdata = mtime[63:32];
            end else if (access_mtimecmp_lo) begin
                rdata = mtimecmp[31:0];
            end else if (access_mtimecmp_hi) begin
                rdata = mtimecmp[63:32];
            end
        end
    end

    // Ready signal - always ready (single cycle access)
    assign ready = req;

    // Timer interrupt - asserted when mtime >= mtimecmp
    assign timer_irq = (mtime >= mtimecmp);

endmodule
