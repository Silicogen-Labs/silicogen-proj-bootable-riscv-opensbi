// simple_bus.sv
// Simple bus arbiter for VexRiscv
// Connects CPU (single master) to multiple slaves (RAM, UART)
// Uses simple valid/ready handshake protocol

module simple_bus (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU instruction bus (master)
    input  logic        ibus_req,
    input  logic [31:0] ibus_addr,
    output logic [31:0] ibus_rdata,
    output logic        ibus_ready,
    output logic        ibus_error,
    
    // CPU data bus (master)
    input  logic        dbus_req,
    input  logic        dbus_we,
    input  logic [31:0] dbus_addr,
    input  logic [31:0] dbus_wdata,
    input  logic [3:0]  dbus_wstrb,
    output logic [31:0] dbus_rdata,
    output logic        dbus_ready,
    output logic        dbus_error,
    
    // RAM interface (slave)
    output logic        ram_req,
    output logic        ram_we,
    output logic [31:0] ram_addr,
    output logic [31:0] ram_wdata,
    output logic [3:0]  ram_wstrb,
    input  logic [31:0] ram_rdata,
    input  logic        ram_ready,
    
    // UART interface (slave)
    output logic        uart_req,
    output logic        uart_we,
    output logic [31:0] uart_addr,
    output logic [31:0] uart_wdata,
    output logic [3:0]  uart_wstrb,
    input  logic [31:0] uart_rdata,
    input  logic        uart_ready,
    
    // Timer interface (slave)
    output logic        timer_req,
    output logic        timer_we,
    output logic [31:0] timer_addr,
    output logic [31:0] timer_wdata,
    output logic [3:0]  timer_wstrb,
    input  logic [31:0] timer_rdata,
    input  logic        timer_ready
);

    // Memory map (from memory_map.md)
    // RAM:   0x00000000 - 0x003FFFFF (4MB)
    // TIMER: 0x02000000 - 0x02FFFFFF (16MB, RISC-V standard CLINT region)
    // UART:  0x10000000 - 0x100000FF (256 bytes)
    
    // Address decode
    logic ibus_to_ram, ibus_to_uart, ibus_to_timer, ibus_unmapped;
    logic dbus_to_ram, dbus_to_uart, dbus_to_timer, dbus_unmapped;
    
    always_comb begin
        // Instruction bus decode
        ibus_to_ram = (ibus_addr >= 32'h00000000) && (ibus_addr < 32'h00400000);
        ibus_to_timer = (ibus_addr >= 32'h02000000) && (ibus_addr < 32'h03000000);
        ibus_to_uart = (ibus_addr >= 32'h10000000) && (ibus_addr < 32'h10000100);
        ibus_unmapped = !(ibus_to_ram || ibus_to_timer || ibus_to_uart);
        
        // Data bus decode
        dbus_to_ram = (dbus_addr >= 32'h00000000) && (dbus_addr < 32'h00400000);
        dbus_to_timer = (dbus_addr >= 32'h02000000) && (dbus_addr < 32'h03000000);
        dbus_to_uart = (dbus_addr >= 32'h10000000) && (dbus_addr < 32'h10000100);
        dbus_unmapped = !(dbus_to_ram || dbus_to_timer || dbus_to_uart);
    end
    
    // Arbitration: instruction bus has lower priority than data bus
    // Simple priority scheme: data bus wins if both request same slave
    logic ibus_grant, dbus_grant;
    
    always_comb begin
        // Grant logic
        if (dbus_req) begin
            dbus_grant = 1'b1;
            ibus_grant = 1'b0;  // Data bus has priority
        end else if (ibus_req) begin
            dbus_grant = 1'b0;
            ibus_grant = 1'b1;
        end else begin
            dbus_grant = 1'b0;
            ibus_grant = 1'b0;
        end
    end
    
    // RAM interface routing
    always_comb begin
        ram_req = 1'b0;
        ram_we = 1'b0;
        ram_addr = 32'h0;
        ram_wdata = 32'h0;
        ram_wstrb = 4'h0;
        
        if (dbus_grant && dbus_to_ram) begin
            ram_req = dbus_req;
            ram_we = dbus_we;
            ram_addr = dbus_addr;
            ram_wdata = dbus_wdata;
            ram_wstrb = dbus_wstrb;
        end else if (ibus_grant && ibus_to_ram) begin
            ram_req = ibus_req;
            ram_we = 1'b0;  // Instruction fetch is always read
            ram_addr = ibus_addr;
            ram_wdata = 32'h0;
            ram_wstrb = 4'hF;  // Full word read
        end
    end
    
    // UART interface routing
    always_comb begin
        uart_req = 1'b0;
        uart_we = 1'b0;
        uart_addr = 32'h0;
        uart_wdata = 32'h0;
        uart_wstrb = 4'h0;
        
        if (dbus_grant && dbus_to_uart) begin
            uart_req = dbus_req;
            uart_we = dbus_we;
            uart_addr = dbus_addr;
            uart_wdata = dbus_wdata;
            uart_wstrb = dbus_wstrb;
        end else if (ibus_grant && ibus_to_uart) begin
            uart_req = ibus_req;
            uart_we = 1'b0;
            uart_addr = ibus_addr;
            uart_wdata = 32'h0;
            uart_wstrb = 4'hF;
        end
    end
    
    // Timer interface routing
    always_comb begin
        timer_req = 1'b0;
        timer_we = 1'b0;
        timer_addr = 32'h0;
        timer_wdata = 32'h0;
        timer_wstrb = 4'h0;
        
        if (dbus_grant && dbus_to_timer) begin
            timer_req = dbus_req;
            timer_we = dbus_we;
            timer_addr = dbus_addr;
            timer_wdata = dbus_wdata;
            timer_wstrb = dbus_wstrb;
        end else if (ibus_grant && ibus_to_timer) begin
            timer_req = ibus_req;
            timer_we = 1'b0;
            timer_addr = ibus_addr;
            timer_wdata = 32'h0;
            timer_wstrb = 4'hF;
        end
    end
    
    // Response routing for instruction bus
    always_comb begin
        ibus_rdata = 32'h0;
        ibus_ready = 1'b0;
        ibus_error = 1'b0;
        
        if (ibus_grant) begin
            if (ibus_to_ram) begin
                ibus_rdata = ram_rdata;
                ibus_ready = ram_ready;
                ibus_error = 1'b0;
            end else if (ibus_to_timer) begin
                ibus_rdata = timer_rdata;
                ibus_ready = timer_ready;
                ibus_error = 1'b0;
            end else if (ibus_to_uart) begin
                ibus_rdata = uart_rdata;
                ibus_ready = uart_ready;
                ibus_error = 1'b0;
            end else if (ibus_unmapped) begin
                ibus_rdata = 32'h0;
                ibus_ready = 1'b1;  // Respond immediately
                ibus_error = 1'b1;  // Access fault
            end
        end
    end
    
    // Response routing for data bus
    always_comb begin
        dbus_rdata = 32'h0;
        dbus_ready = 1'b0;
        dbus_error = 1'b0;
        
        if (dbus_grant) begin
            if (dbus_to_ram) begin
                dbus_rdata = ram_rdata;
                dbus_ready = ram_ready;
                dbus_error = 1'b0;
            end else if (dbus_to_timer) begin
                dbus_rdata = timer_rdata;
                dbus_ready = timer_ready;
                dbus_error = 1'b0;
            end else if (dbus_to_uart) begin
                dbus_rdata = uart_rdata;
                dbus_ready = uart_ready;
                dbus_error = 1'b0;
            end else if (dbus_unmapped) begin
                dbus_rdata = 32'h0;
                dbus_ready = 1'b1;  // Respond immediately
                dbus_error = 1'b1;  // Access fault
            end
        end
    end

endmodule
