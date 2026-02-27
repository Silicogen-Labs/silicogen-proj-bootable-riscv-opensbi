// csr_file.sv
// Control and Status Registers (CSR) for RISC-V RV32IMAZicsr
// Implements all CSRs required for OpenSBI boot

module csr_file (
    input  logic        clk,
    input  logic        rst_n,
    
    // CSR access interface
    input  logic [11:0] csr_addr,
    input  logic [31:0] csr_wdata,
    input  logic [1:0]  csr_op,      // 00=none, 01=RW, 10=RS, 11=RC
    input  logic        csr_we,
    output logic [31:0] csr_rdata,
    output logic        csr_illegal,
    
    // Trap interface
    input  logic        trap_taken,
    input  logic [31:0] trap_pc,
    input  logic [3:0]  trap_cause,
    input  logic [31:0] trap_value,
    input  logic        is_interrupt,
    
    // MRET interface
    input  logic        mret,
    output logic [31:0] mtvec_base,
    output logic [31:0] mepc_out,
    
    // Interrupt enable outputs
    output logic        mstatus_mie_out,
    output logic        mie_mtie_out,
    output logic        mie_msie_out,
    output logic        mip_msip_out,
    
    // Counter inputs
    input  logic        count_cycle,
    input  logic        count_instret,
    
    // Interrupt inputs
    input  logic        timer_irq
);

    // CSR address definitions
    localparam logic [11:0] CSR_MISA      = 12'h301;
    localparam logic [11:0] CSR_MVENDORID = 12'hF11;
    localparam logic [11:0] CSR_MARCHID   = 12'hF12;
    localparam logic [11:0] CSR_MIMPID    = 12'hF13;
    localparam logic [11:0] CSR_MHARTID   = 12'hF14;
    localparam logic [11:0] CSR_MSTATUS   = 12'h300;
    localparam logic [11:0] CSR_MTVEC     = 12'h305;
    localparam logic [11:0] CSR_MEPC      = 12'h341;
    localparam logic [11:0] CSR_MCAUSE    = 12'h342;
    localparam logic [11:0] CSR_MTVAL     = 12'h343;
    localparam logic [11:0] CSR_MSCRATCH  = 12'h340;
    localparam logic [11:0] CSR_MIE       = 12'h304;
    localparam logic [11:0] CSR_MIP       = 12'h344;
    localparam logic [11:0] CSR_MCYCLE    = 12'hB00;
    localparam logic [11:0] CSR_MCYCLEH   = 12'hB80;
    localparam logic [11:0] CSR_MINSTRET  = 12'hB02;
    localparam logic [11:0] CSR_MINSTRETH = 12'hB82;
    localparam logic [11:0] CSR_CYCLE     = 12'hC00;
    localparam logic [11:0] CSR_CYCLEH    = 12'hC80;
    localparam logic [11:0] CSR_TIME      = 12'hC01;
    localparam logic [11:0] CSR_TIMEH     = 12'hC81;
    localparam logic [11:0] CSR_INSTRET   = 12'hC02;
    localparam logic [11:0] CSR_INSTRETH  = 12'hC82;
    // Entropy source (Zkr extension) - needed for stack canary generation
    localparam logic [11:0] CSR_SEED      = 12'h015;
    // Supervisor-mode CSRs (stubs - write ignored, read zero)
    localparam logic [11:0] CSR_SSTATUS   = 12'h100;
    localparam logic [11:0] CSR_SIE       = 12'h104;
    localparam logic [11:0] CSR_STVEC     = 12'h105;
    localparam logic [11:0] CSR_SCOUNTEREN= 12'h106;
    localparam logic [11:0] CSR_SSCRATCH  = 12'h140;
    localparam logic [11:0] CSR_SEPC      = 12'h141;
    localparam logic [11:0] CSR_SCAUSE    = 12'h142;
    localparam logic [11:0] CSR_STVAL     = 12'h143;
    localparam logic [11:0] CSR_SIP       = 12'h144;
    localparam logic [11:0] CSR_SATP      = 12'h180;
    // Machine-mode extension CSRs (stubs)
    localparam logic [11:0] CSR_MSTATUSH  = 12'h310;  // RV32 mstatus high
    localparam logic [11:0] CSR_MEDELEG   = 12'h302;
    localparam logic [11:0] CSR_MIDELEG   = 12'h303;
    localparam logic [11:0] CSR_MCOUNTEREN= 12'h306;
    localparam logic [11:0] CSR_MCOUNTINHIBIT = 12'h320;
    // PMP CSRs (stubs - 16 pmpaddr + 4 pmpcfg)
    localparam logic [11:0] CSR_PMPCFG0   = 12'h3A0;
    localparam logic [11:0] CSR_PMPCFG1   = 12'h3A1;
    localparam logic [11:0] CSR_PMPCFG2   = 12'h3A2;
    localparam logic [11:0] CSR_PMPCFG3   = 12'h3A3;

    // CSR operation encodings
    localparam logic [1:0] CSR_OP_NONE = 2'b00;
    localparam logic [1:0] CSR_OP_RW   = 2'b01;
    localparam logic [1:0] CSR_OP_RS   = 2'b10;
    localparam logic [1:0] CSR_OP_RC   = 2'b11;

    // Machine Information Registers (Read-Only)
    localparam logic [31:0] MISA_VALUE   = 32'h40141101;  // RV32IMA
    localparam logic [31:0] MVENDORID_VALUE = 32'h00000000;
    localparam logic [31:0] MARCHID_VALUE   = 32'h00000000;
    localparam logic [31:0] MIMPID_VALUE    = 32'h00000001;
    localparam logic [31:0] MHARTID_VALUE   = 32'h00000000;

    // Machine Status Register (mstatus)
    logic [31:0] mstatus;
    logic        mstatus_mie;   // [3] Machine Interrupt Enable
    logic        mstatus_mpie;  // [7] Previous MIE
    logic [1:0]  mstatus_mpp;   // [12:11] Previous Privilege Mode

    // Machine Trap-Vector Base Address Register (mtvec)
    logic [31:0] mtvec;

    // Machine Exception Program Counter (mepc)
    logic [31:0] mepc;

    // Machine Cause Register (mcause)
    logic [31:0] mcause;

    // Machine Trap Value Register (mtval)
    logic [31:0] mtval;

    // Machine Scratch Register (mscratch)
    logic [31:0] mscratch;

    // Machine Interrupt Enable (mie)
    logic [31:0] mie;

    // Machine Interrupt Pending (mip)
    logic [31:0] mip;
    logic        mip_msip;  // [3] Machine Software Interrupt Pending (writable)
    
    // Update mip with interrupt inputs (MTIP is read-only, driven by timer_irq)
    always_comb begin
        mip = 32'h0;
        mip[3] = mip_msip;     // MSIP - software interrupt (writable)
        mip[7] = timer_irq;    // MTIP - timer interrupt (read-only, driven by hardware)
    end

    // Machine Cycle Counter (mcycle/mcycleh)
    logic [63:0] mcycle;

    // Machine Instructions-Retired Counter (minstret/minstreth)
    logic [63:0] minstret;

    // Pack mstatus register
    always_comb begin
        mstatus = 32'h0;
        mstatus[3]     = mstatus_mie;
        mstatus[7]     = mstatus_mpie;
        mstatus[12:11] = mstatus_mpp;
    end

    // CSR read logic
    always_comb begin
        csr_rdata = 32'h0;
        csr_illegal = 1'b0;
        
        case (csr_addr)
            // Machine Information Registers
            CSR_MISA:      csr_rdata = MISA_VALUE;
            CSR_MVENDORID: csr_rdata = MVENDORID_VALUE;
            CSR_MARCHID:   csr_rdata = MARCHID_VALUE;
            CSR_MIMPID:    csr_rdata = MIMPID_VALUE;
            CSR_MHARTID:   csr_rdata = MHARTID_VALUE;
            
            // Machine Trap Setup
            CSR_MSTATUS:   csr_rdata = mstatus;
            CSR_MTVEC:     csr_rdata = mtvec;
            CSR_MIE:       csr_rdata = mie;
            
            // Machine Trap Handling
            CSR_MSCRATCH:  csr_rdata = mscratch;
            CSR_MEPC:      csr_rdata = mepc;
            CSR_MCAUSE:    csr_rdata = mcause;
            CSR_MTVAL:     csr_rdata = mtval;
            CSR_MIP:       csr_rdata = mip;
            
            // Machine Counters
            CSR_MCYCLE:    csr_rdata = mcycle[31:0];
            CSR_MCYCLEH:   csr_rdata = mcycle[63:32];
            CSR_MINSTRET:  csr_rdata = minstret[31:0];
            CSR_MINSTRETH: csr_rdata = minstret[63:32];
            
            // User Counters (shadows of machine counters)
            CSR_CYCLE:     csr_rdata = mcycle[31:0];
            CSR_CYCLEH:    csr_rdata = mcycle[63:32];
            CSR_TIME:      csr_rdata = mcycle[31:0];      // Same as cycle for now
            CSR_TIMEH:     csr_rdata = mcycle[63:32];
            CSR_INSTRET:   csr_rdata = minstret[31:0];
            CSR_INSTRETH:  csr_rdata = minstret[63:32];
            
            // Entropy source: status=ES16 (2'b10), entropy from cycle counter
            // Stack canary loop checks bits[31:30] >= 2'b10 to exit
            CSR_SEED: csr_rdata = {2'b10, mcycle[29:0]};
            
            // Supervisor-mode CSRs: read as zero (OpenSBI writes these, no trap needed)
            CSR_SSTATUS, CSR_SIE, CSR_STVEC, CSR_SCOUNTEREN,
            CSR_SSCRATCH, CSR_SEPC, CSR_SCAUSE, CSR_STVAL,
            CSR_SIP, CSR_SATP: csr_rdata = 32'h0;
            
            // Machine extension CSRs: read as zero
            CSR_MSTATUSH, CSR_MEDELEG, CSR_MIDELEG,
            CSR_MCOUNTEREN, CSR_MCOUNTINHIBIT: csr_rdata = 32'h0;
            
            // PMP CSRs: read as zero (no PMP implemented)
            CSR_PMPCFG0, CSR_PMPCFG1, CSR_PMPCFG2, CSR_PMPCFG3: csr_rdata = 32'h0;
            
            default: begin
                // Unknown CSR: return 0, no illegal trap
                // OpenSBI probes many optional CSRs; trapping would abort boot
                csr_rdata   = 32'h0;
                csr_illegal = 1'b0;
            end
        endcase
    end

    // CSR write logic
    logic [31:0] csr_write_data;
    
    always_comb begin
        case (csr_op)
            CSR_OP_RW:   csr_write_data = csr_wdata;
            CSR_OP_RS:   csr_write_data = csr_rdata | csr_wdata;
            CSR_OP_RC:   csr_write_data = csr_rdata & ~csr_wdata;
            default:     csr_write_data = csr_rdata;
        endcase
    end

    // CSR sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mstatus_mpp  <= 2'b11;  // Machine mode
            mtvec        <= 32'h00000000;
            mepc         <= 32'h00000000;
            mcause       <= 32'h00000000;
            mtval        <= 32'h00000000;
            mscratch     <= 32'h00000000;
            mie          <= 32'h00000000;
            mip_msip     <= 1'b0;
            mcycle       <= 64'h0;
            minstret     <= 64'h0;
        end else begin
            // Update cycle counter
            if (count_cycle) begin
                mcycle <= mcycle + 64'h1;
            end
            
            // Update instruction retired counter
            if (count_instret) begin
                minstret <= minstret + 64'h1;
            end
            
            // Trap handling
            if (trap_taken) begin
                // Save current state
                mepc         <= trap_pc;
                mcause       <= is_interrupt ? {1'b1, 27'h0, trap_cause} : {1'b0, 27'h0, trap_cause};
                mtval        <= trap_value;
                mstatus_mpie <= mstatus_mie;
                mstatus_mie  <= 1'b0;         // Disable interrupts
                mstatus_mpp  <= 2'b11;        // Save current privilege (Machine mode)
            end
            // MRET handling
            else if (mret) begin
                mstatus_mie  <= mstatus_mpie;
                mstatus_mpie <= 1'b1;
                mstatus_mpp  <= 2'b00;        // User mode (least privileged)
            end
            // CSR write operations
            else if (csr_we && !csr_illegal) begin
                case (csr_addr)
                    CSR_MSTATUS: begin
                        mstatus_mie  <= csr_write_data[3];
                        mstatus_mpie <= csr_write_data[7];
                        mstatus_mpp  <= csr_write_data[12:11];
                    end
                    
                    CSR_MTVEC: begin
                        // mtvec.MODE must be 0 or 1, bits [1:0]
                        // BASE must be 4-byte aligned
                        mtvec <= {csr_write_data[31:2], 2'b00};
                    end
                    
                    CSR_MEPC: begin
                        // MEPC must be 4-byte aligned (no compressed instructions)
                        mepc <= {csr_write_data[31:2], 2'b00};
                    end
                    
                    CSR_MCAUSE: begin
                        mcause <= csr_write_data;
                    end
                    
                    CSR_MTVAL: begin
                        mtval <= csr_write_data;
                    end
                    
                    CSR_MSCRATCH: begin
                        mscratch <= csr_write_data;
                    end
                    
                    CSR_MIE: begin
                        // Only implement machine-mode interrupt enables
                        mie <= csr_write_data & 32'h00000888;  // MEIE, MTIE, MSIE
                    end
                    
                    CSR_MIP: begin
                        // Software can write MSIP, others are read-only
                        mip_msip <= csr_write_data[3];  // MSIP
                    end
                    
                    CSR_MCYCLE: begin
                        mcycle[31:0] <= csr_write_data;
                    end
                    
                    CSR_MCYCLEH: begin
                        mcycle[63:32] <= csr_write_data;
                    end
                    
                    CSR_MINSTRET: begin
                        minstret[31:0] <= csr_write_data;
                    end
                    
                    CSR_MINSTRETH: begin
                        minstret[63:32] <= csr_write_data;
                    end
                    
                    // Read-only registers - ignore writes
                    CSR_MISA, CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID,
                    CSR_CYCLE, CSR_CYCLEH, CSR_TIME, CSR_TIMEH,
                    CSR_INSTRET, CSR_INSTRETH,
                    // Seed is read-only (write of 0 is used to poll)
                    CSR_SEED,
                    // Supervisor-mode stubs: accept writes silently
                    CSR_SSTATUS, CSR_SIE, CSR_STVEC, CSR_SCOUNTEREN,
                    CSR_SSCRATCH, CSR_SEPC, CSR_SCAUSE, CSR_STVAL,
                    CSR_SIP, CSR_SATP,
                    // Machine extension stubs: accept writes silently
                    CSR_MSTATUSH, CSR_MEDELEG, CSR_MIDELEG,
                    CSR_MCOUNTEREN, CSR_MCOUNTINHIBIT,
                    // PMP stubs: accept writes silently
                    CSR_PMPCFG0, CSR_PMPCFG1, CSR_PMPCFG2, CSR_PMPCFG3: begin
                        // No write
                    end
                    
                    default: begin
                        // Unknown CSR write: silently ignore (no trap)
                    end
                endcase
            end
        end
    end

    // Output assignments
    assign mtvec_base      = mtvec;
    assign mepc_out        = mepc;
    assign mstatus_mie_out = mstatus_mie;
    assign mie_mtie_out    = mie[7];  // MTIE bit
    assign mie_msie_out    = mie[3];  // MSIE bit
    assign mip_msip_out    = mip_msip; // MSIP bit

endmodule
