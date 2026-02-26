// riscv_soc.sv
// Top-level RISC-V SoC integrating CPU, RAM, UART, Timer, and bus
// Memory map:
//   RAM:   0x00000000 - 0x003FFFFF (4MB)
//   TIMER: 0x02000000 - 0x02FFFFFF (16MB, RISC-V standard CLINT region)
//   UART:  0x10000000 - 0x100000FF (256 bytes)

module riscv_soc #(
    parameter MEM_INIT_FILE = ""
)(
    input  logic clk,
    input  logic rst_n,
    
    // UART TX output
    output logic uart_tx
);

    // Instruction bus signals
    logic        ibus_req;
    logic [31:0] ibus_addr;
    logic [31:0] ibus_rdata;
    logic        ibus_ready;
    logic        ibus_error;
    
    // Data bus signals
    logic        dbus_req;
    logic        dbus_we;
    logic [31:0] dbus_addr;
    logic [31:0] dbus_wdata;
    logic [3:0]  dbus_wstrb;
    logic [31:0] dbus_rdata;
    logic        dbus_ready;
    logic        dbus_error;
    
    // RAM interface
    logic        ram_req;
    logic        ram_we;
    logic [31:0] ram_addr;
    logic [31:0] ram_wdata;
    logic [3:0]  ram_wstrb;
    logic [31:0] ram_rdata;
    logic        ram_ready;
    
    // UART interface
    logic        uart_req;
    logic        uart_we;
    logic [31:0] uart_addr;
    logic [31:0] uart_wdata;
    logic [3:0]  uart_wstrb;
    logic [31:0] uart_rdata;
    logic        uart_ready;
    
    // Timer interface
    logic        timer_req;
    logic        timer_we;
    logic [31:0] timer_addr;
    logic [31:0] timer_wdata;
    logic [3:0]  timer_wstrb;  // Not used by timer module
    logic [31:0] timer_rdata;
    logic        timer_ready;
    logic        timer_irq;
    
    // ========================
    // CPU Core Instantiation
    // ========================
    
    cpu_core u_cpu_core (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Interrupts
        .timer_irq  (timer_irq),
        
        // Instruction bus
        .ibus_req   (ibus_req),
        .ibus_addr  (ibus_addr),
        .ibus_rdata (ibus_rdata),
        .ibus_ready (ibus_ready),
        .ibus_error (ibus_error),
        
        // Data bus
        .dbus_req   (dbus_req),
        .dbus_we    (dbus_we),
        .dbus_addr  (dbus_addr),
        .dbus_wdata (dbus_wdata),
        .dbus_wstrb (dbus_wstrb),
        .dbus_rdata (dbus_rdata),
        .dbus_ready (dbus_ready),
        .dbus_error (dbus_error)
    );
    
    // ========================
    // Bus Arbiter
    // ========================
    
    simple_bus u_simple_bus (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // CPU instruction bus
        .ibus_req   (ibus_req),
        .ibus_addr  (ibus_addr),
        .ibus_rdata (ibus_rdata),
        .ibus_ready (ibus_ready),
        .ibus_error (ibus_error),
        
        // CPU data bus
        .dbus_req   (dbus_req),
        .dbus_we    (dbus_we),
        .dbus_addr  (dbus_addr),
        .dbus_wdata (dbus_wdata),
        .dbus_wstrb (dbus_wstrb),
        .dbus_rdata (dbus_rdata),
        .dbus_ready (dbus_ready),
        .dbus_error (dbus_error),
        
        // RAM interface
        .ram_req    (ram_req),
        .ram_we     (ram_we),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_wstrb  (ram_wstrb),
        .ram_rdata  (ram_rdata),
        .ram_ready  (ram_ready),
        
        // UART interface
        .uart_req   (uart_req),
        .uart_we    (uart_we),
        .uart_addr  (uart_addr),
        .uart_wdata (uart_wdata),
        .uart_wstrb (uart_wstrb),
        .uart_rdata (uart_rdata),
        .uart_ready (uart_ready),
        
        // Timer interface
        .timer_req   (timer_req),
        .timer_we    (timer_we),
        .timer_addr  (timer_addr),
        .timer_wdata (timer_wdata),
        .timer_wstrb (timer_wstrb),
        .timer_rdata (timer_rdata),
        .timer_ready (timer_ready)
    );
    
    // ========================
    // RAM (4MB)
    // ========================
    
    ram #(
        .ADDR_WIDTH(22),  // 4MB
        .DATA_WIDTH(32),
        .MEM_INIT_FILE(MEM_INIT_FILE)
    ) u_ram (
        .clk    (clk),
        .rst_n  (rst_n),
        .req    (ram_req),
        .we     (ram_we),
        .addr   (ram_addr),
        .wdata  (ram_wdata),
        .wstrb  (ram_wstrb),
        .rdata  (ram_rdata),
        .ready  (ram_ready)
    );
    
    // ========================
    // UART 16550
    // ========================
    
    uart_16550 u_uart (
        .clk    (clk),
        .rst_n  (rst_n),
        .req    (uart_req),
        .we     (uart_we),
        .addr   (uart_addr),
        .wdata  (uart_wdata),
        .wstrb  (uart_wstrb),
        .rdata  (uart_rdata),
        .ready  (uart_ready),
        .uart_tx(uart_tx)
    );
    
    // ========================
    // Timer (RISC-V CLINT)
    // ========================
    
    timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .req      (timer_req),
        .we       (timer_we),
        .addr     (timer_addr),
        .wdata    (timer_wdata),
        .rdata    (timer_rdata),
        .ready    (timer_ready),
        .timer_irq(timer_irq)
    );

endmodule
