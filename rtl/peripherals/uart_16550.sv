// uart_16550.sv
// Simple UART 16550 compatible controller
// Transmit-only implementation (sufficient for initial OpenSBI boot)
// Implements minimal register set for OpenSBI compatibility

module uart_16550 (
    input  logic        clk,
    input  logic        rst_n,
    
    // Bus interface
    input  logic        req,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    output logic [31:0] rdata,
    output logic        ready,
    
    // UART TX pin
    output logic        uart_tx
);

    // Register offsets (from memory_map.md)
    localparam ADDR_RBR_THR_DLL = 3'h0;  // 0x00
    localparam ADDR_IER_DLM     = 3'h1;  // 0x01
    localparam ADDR_IIR_FCR     = 3'h2;  // 0x02
    localparam ADDR_LCR         = 3'h3;  // 0x03
    localparam ADDR_MCR         = 3'h4;  // 0x04
    localparam ADDR_LSR         = 3'h5;  // 0x05
    localparam ADDR_MSR         = 3'h6;  // 0x06
    localparam ADDR_SCR         = 3'h7;  // 0x07
    
    // Registers
    logic [7:0] dll, dlm;        // Divisor latch
    logic [7:0] ier;             // Interrupt enable
    logic [7:0] lcr;             // Line control
    logic [7:0] mcr;             // Modem control
    logic [7:0] scr;             // Scratch
    logic [7:0] thr;             // Transmitter holding register
    
    // Line Status Register bits
    logic lsr_dr;                // Data ready
    logic lsr_thre;              // Transmitter holding register empty
    logic lsr_temt;              // Transmitter empty
    
    // Internal signals
    logic [2:0] reg_addr;
    logic       dlab;            // Divisor latch access bit
    logic       tx_busy;
    logic [3:0] tx_bit_count;
    logic [9:0] tx_shift_reg;    // Start bit + 8 data bits + stop bit
    logic [15:0] baud_counter;
    logic [15:0] baud_divisor;
    
    assign reg_addr = addr[4:2];  // Word addressing: register N at word offset N (reg_shift=2)
    assign dlab = lcr[7];
    assign baud_divisor = {dlm, dll};
    
    // Initialize TX line to idle (high)
    initial begin
        uart_tx = 1'b1;
    end
    
    // Register writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dll <= 8'h01;  // Default divisor
            dlm <= 8'h00;
            ier <= 8'h00;
            lcr <= 8'h03;  // 8N1 (8 data bits, no parity, 1 stop bit)
            mcr <= 8'h00;
            scr <= 8'h00;
            thr <= 8'h00;
        end else if (req && we) begin
            case (reg_addr)
                ADDR_RBR_THR_DLL: begin
                    if (dlab) begin
                        dll <= wdata[7:0];  // Divisor latch LSB
                    end else begin
                        thr <= wdata[7:0];  // Transmit holding register
                    end
                end
                ADDR_IER_DLM: begin
                    if (dlab) begin
                        dlm <= wdata[7:0];  // Divisor latch MSB
                    end else begin
                        ier <= wdata[7:0];  // Interrupt enable
                    end
                end
                ADDR_LCR: lcr <= wdata[7:0];
                ADDR_MCR: mcr <= wdata[7:0];
                ADDR_SCR: scr <= wdata[7:0];
                default: ;
            endcase
        end
    end
    
    // Register reads
    always_comb begin
        logic [7:0] reg_data;
        rdata = 32'h0;
        reg_data = 8'h0;
        
        if (req && !we) begin
            case (reg_addr)
                ADDR_RBR_THR_DLL: begin
                    if (dlab) begin
                        reg_data = dll;
                    end else begin
                        reg_data = 8'h0;  // RBR not implemented
                    end
                end
                ADDR_IER_DLM: begin
                    if (dlab) begin
                        reg_data = dlm;
                    end else begin
                        reg_data = ier;
                    end
                end
                ADDR_IIR_FCR: reg_data = 8'h01;  // No interrupt pending
                ADDR_LCR: reg_data = lcr;
                ADDR_MCR: reg_data = mcr;
                ADDR_LSR: begin
                    // LSR[5] = THRE (transmitter holding register empty)
                    // LSR[6] = TEMT (transmitter empty)
                    // Both set to 1 when not transmitting
                    reg_data = {2'b0, lsr_temt, lsr_thre, 4'b0};
                end
                ADDR_MSR: reg_data = 8'hB0;  // Modem status (dummy values)
                ADDR_SCR: reg_data = scr;
                default: reg_data = 8'h0;
            endcase
            // Replicate byte data across all lanes for byte-addressable access
            rdata = {reg_data, reg_data, reg_data, reg_data};
        end
    end
    
    // Transmitter state machine (simplified - instant transmission for simulation)
    // In real hardware, this would shift bits out at the baud rate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy <= 1'b0;
            tx_bit_count <= 4'h0;
            tx_shift_reg <= 10'h3FF;  // Idle state
            baud_counter <= 16'h0;
            uart_tx <= 1'b1;
        end else begin
            // Check for new transmit request
            if (req && we && (reg_addr == ADDR_RBR_THR_DLL) && !dlab && !tx_busy) begin
                // Load transmit shift register
                // Format: start(0) + data[7:0] + stop(1)
                tx_shift_reg <= {1'b1, wdata[7:0], 1'b0};
                tx_busy <= 1'b1;
                tx_bit_count <= 4'd10;  // 1 start + 8 data + 1 stop
                baud_counter <= baud_divisor;
            end
            
            // Transmit state machine
            if (tx_busy) begin
                if (baud_counter == 16'h0) begin
                    // Shift out one bit
                    uart_tx <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    tx_bit_count <= tx_bit_count - 1;
                    baud_counter <= baud_divisor;
                    
                    if (tx_bit_count == 4'h1) begin
                        tx_busy <= 1'b0;
                        uart_tx <= 1'b1;  // Return to idle
                    end
                end else begin
                    baud_counter <= baud_counter - 1;
                end
            end else begin
                uart_tx <= 1'b1;  // Idle state (high)
            end
        end
    end
    
    // Status signals
    assign lsr_thre = !tx_busy;  // THR empty when not transmitting
    assign lsr_temt = !tx_busy;  // Transmitter empty when not transmitting
    assign lsr_dr = 1'b0;        // No receive capability
    
    // Ready signal - respond immediately
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= req;
        end
    end

endmodule
