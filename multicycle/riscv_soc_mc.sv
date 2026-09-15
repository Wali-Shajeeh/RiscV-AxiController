// =============================================================
// riscv_core_mc.sv — Multicycle RV32I Top Level
// =============================================================
// Differences from single-cycle riscv_core.sv:
//   1. Intermediate registers: IR, A, B, ALUOut, MDR
//   2. FSM controller (controller_fsm) replaces decoder + pc_control
//   3. PC updates only when FSM asserts pc_write
//   4. Instruction fields decoded from IR (not live instruction)
//   5. ALU operand A mux adds pc_saved option
//   6. Writeback mux adds MDR and link-address options
//   7. PC-next mux adds JALR target option
// =============================================================

module riscv_soc_mc (
    input  logic clk,
    input  logic reset,
    output logic pwm_out
);

    // ================ Program Counter ================
    logic [31:0] pc_current, pc_next;

    // ================ Instruction path ================
    logic [31:0] instruction;       // raw output from instr_mem
    logic [31:0] IR;                // Instruction Register (latched in FETCH)
    logic [31:0] pc_saved;          // PC of current instruction (saved in FETCH)

    // ================ Decoded fields from IR ================
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1, rs2, rd;

    assign opcode = IR[6:0];
    assign rd     = IR[11:7];
    assign funct3 = IR[14:12];
    assign rs1    = IR[19:15];
    assign rs2    = IR[24:20];
    assign funct7 = IR[31:25];

    // ================ Register file ================
    logic [31:0] read_data1, read_data2;    // combinational reg file outputs
    logic [31:0] A, B;                      // latched register values
    logic [31:0] write_data_reg;            // data to write back to reg file

    // ================ Immediate ================
    logic [31:0] imm;

    // ================ ALU ================
    logic [31:0] alu_operand_a, alu_operand_b;
    logic [31:0] alu_result;                // combinational ALU output
    logic [31:0] ALUOut;                    // registered ALU result
    logic        zero_flag;
    logic [3:0]  alu_control_sig;

    // ================ Data memory ================
    logic [31:0] mem_read_data;             // combinational data mem output
    logic [31:0] MDR;                       // Memory Data Register

    // ================ Control signals from FSM ================
    logic        ir_write;
    logic        pc_write;
    logic [1:0]  pc_src;
    logic        reg_write;
    logic [1:0]  reg_write_src;
    logic        alu_src_b;
    logic [1:0]  alu_src_a;
    logic [1:0]  alu_op;
    logic        mem_read, mem_write;

    // ================ AXI4-Lite & Peripheral ================
    logic        is_peripheral_access;
    logic        mem_ready;
    logic [31:0] axi_read_data;
    logic [31:0] combined_read_data;
    
    assign is_peripheral_access = (ALUOut >= 32'h4000_0000);
    assign combined_read_data   = is_peripheral_access ? axi_read_data : mem_read_data;

    // AXI Interconnect to PWM Wires
    logic [31:0] pwm_awaddr, axi_awaddr;
    logic        pwm_awvalid, axi_awvalid;
    logic        pwm_awready, axi_awready;
    logic [31:0] pwm_wdata, axi_wdata;
    logic [3:0]  pwm_wstrb, axi_wstrb;
    logic        pwm_wvalid, axi_wvalid;
    logic        pwm_wready, axi_wready;
    logic [1:0]  pwm_bresp, axi_bresp;
    logic        pwm_bvalid, axi_bvalid;
    logic        pwm_bready, axi_bready;
    logic [31:0] pwm_araddr, axi_araddr;
    logic        pwm_arvalid, axi_arvalid;
    logic        pwm_arready, axi_arready;
    logic [31:0] pwm_rdata, axi_rdata;
    logic [1:0]  pwm_rresp, axi_rresp;
    logic        pwm_rvalid, axi_rvalid;
    logic        pwm_rready, axi_rready;


    // ==========================================================
    //  PC Register — only updates when pc_write is asserted
    // ==========================================================
    pc_reg u_pc_reg (
        .clk      (clk),
        .reset    (reset),
        .pc_write (pc_write),       // CHANGED: gated write enable
        .pc_next  (pc_next),
        .pc_out   (pc_current)
    );


    // ==========================================================
    //  Instruction Memory — reads at pc_current (combinational)
    // ==========================================================
    instr_mem u_instr_mem (
        .clk         (clk),
        .addr        (pc_current),
        .instruction (instruction)
    );


    // ==========================================================
    //  Instruction Register (IR) + Saved PC
    //  — Latched only in FETCH state (ir_write = 1)
    //  — Stable during DECODE, EXECUTE, MEMORY, WRITEBACK
    // ==========================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            IR       <= 32'b0;
            pc_saved <= 32'b0;
        end else if (ir_write) begin
            IR       <= instruction;
            pc_saved <= pc_current;     // save PC of this instruction
        end
    end


    // ==========================================================
    //  Register File
    // ==========================================================
    reg_file u_reg_file (
        .clk         (clk),
        .reset       (reset),
        .rs1         (rs1),
        .rs2         (rs2),
        .rd          (rd),
        .write_data  (write_data_reg),
        .reg_write   (reg_write),
        .read_data1  (read_data1),
        .read_data2  (read_data2)
    );


    // ==========================================================
    //  A, B Registers — latch reg file outputs every cycle
    //  (Values are stable as long as IR doesn't change)
    // ==========================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            A <= 32'b0;
            B <= 32'b0;
        end else begin
            A <= read_data1;
            B <= read_data2;
        end
    end


    // ==========================================================
    //  Immediate Generator — combinational from IR
    // ==========================================================
    imm_gen u_imm_gen (
        .instruction (IR),          // CHANGED: reads from IR, not live instruction
        .imm_out     (imm)
    );


    // ==========================================================
    //  ALU Control — decodes funct3/funct7 with alu_op hint
    // ==========================================================
    alu_control u_alu_control (
        .alu_op      (alu_op),
        .funct3      (funct3),
        .funct7      (funct7),
        .alu_control (alu_control_sig)
    );


    // ==========================================================
    //  ALU Operand A Mux
    //    00 = A register (rs1)     — R/I-type, Load, Store, Branch, JALR
    //    01 = pc_saved              — AUIPC
    //    10 = zero                  — LUI (0 + imm = imm)
    // ==========================================================
    always_comb begin
        case (alu_src_a)
            2'b00:   alu_operand_a = A;             // latched rs1
            2'b01:   alu_operand_a = pc_saved;      // saved PC
            2'b10:   alu_operand_a = 32'b0;         // zero (LUI)
            default: alu_operand_a = A;
        endcase
    end


    // ==========================================================
    //  ALU Operand B Mux
    //    0 = B register (rs2)   — R-type, Branch
    //    1 = immediate          — I-type, Load, Store, LUI, AUIPC, JALR
    // ==========================================================
    assign alu_operand_b = (alu_src_b) ? imm : B;


    // ==========================================================
    //  ALU
    // ==========================================================
    alu u_alu (
        .operand_a   (alu_operand_a),
        .operand_b   (alu_operand_b),
        .alu_control (alu_control_sig),
        .alu_result  (alu_result),
        .zero_flag   (zero_flag)
    );


    // ==========================================================
    //  ALUOut Register — latches ALU result every cycle
    //  Used in WRITEBACK (R/I/LUI/AUIPC) and MEMORY (address)
    // ==========================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            ALUOut <= 32'b0;
        else
            ALUOut <= alu_result;
    end


    // ==========================================================
    //  Data Memory — address from ALUOut (computed in EXECUTE)
    // ==========================================================
    data_mem u_data_mem (
        .clk         (clk),
        .addr        (ALUOut),          // registered address from EXECUTE
        .write_data  (B),               // store data from B register
        .mem_read    (mem_read & ~is_peripheral_access),
        .mem_write   (mem_write & ~is_peripheral_access),
        .funct3      (funct3),          // byte/half/word select
        .read_data   (mem_read_data)
    );


    // ==========================================================
    //  Memory Data Register (MDR) — latches mem read every cycle
    //  Used in WRITEBACK for load instructions
    // ==========================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            MDR <= 32'b0;
        else
            MDR <= combined_read_data;
    end


    // ==========================================================
    //  Writeback Mux — selects data for register file write
    //    00 = ALUOut           (R-type, I-type, LUI, AUIPC)
    //    01 = MDR              (Load)
    //    10 = pc_saved + 4     (JAL/JALR return address)
    // ==========================================================
    always_comb begin
        case (reg_write_src)
            2'b00:   write_data_reg = ALUOut;
            2'b01:   write_data_reg = MDR;
            2'b10:   write_data_reg = pc_saved + 32'd4;
            default: write_data_reg = ALUOut;
        endcase
    end


    // ==========================================================
    //  PC Next Mux — selects next PC value
    //    00 = PC + 4            (sequential, in FETCH)
    //    01 = pc_saved + imm    (branch taken / JAL)
    //    10 = alu_result & ~1   (JALR target, computed by ALU)
    // ==========================================================
    always_comb begin
        case (pc_src)
            2'b00:   pc_next = pc_current + 32'd4;
            2'b01:   pc_next = pc_saved + imm;
            2'b10:   pc_next = alu_result & ~32'b1;    // JALR: LSB cleared per spec
            default: pc_next = pc_current + 32'd4;
        endcase
    end


    // ==========================================================
    //  FSM Controller
    // ==========================================================
    controller_fsm u_controller (
        .clk           (clk),
        .reset         (reset),
        .opcode        (opcode),
        .funct3        (funct3),
        .zero_flag     (zero_flag),
        .alu_lt_result (alu_result[0]),     // SLT/SLTU result bit (combinational)
        .mem_ready     (mem_ready),         // from AXI/memory
        // Control outputs
        .ir_write      (ir_write),
        .pc_write      (pc_write),
        .pc_src        (pc_src),
        .reg_write     (reg_write),
        .reg_write_src (reg_write_src),
        .alu_src_b     (alu_src_b),
        .alu_src_a     (alu_src_a),
        .alu_op        (alu_op),
        .mem_read      (mem_read),
        .mem_write     (mem_write)
    );

    // ==========================================================
    //  AXI4-Lite Adapter
    // ==========================================================
    axi_adapter u_axi_adapter (
        .clk         (clk),
        .reset       (reset),
        .addr        (ALUOut),
        .write_data  (B),
        .read_req    (mem_read  & is_peripheral_access),
        .write_req   (mem_write & is_peripheral_access),
        .read_data   (axi_read_data),
        .mem_ready   (mem_ready),

        .awaddr  (axi_awaddr),
        .awvalid (axi_awvalid),
        .awready (axi_awready),
        .wdata   (axi_wdata),
        .wstrb   (axi_wstrb),
        .wvalid  (axi_wvalid),
        .wready  (axi_wready),
        .bresp   (axi_bresp),
        .bvalid  (axi_bvalid),
        .bready  (axi_bready),
        .araddr  (axi_araddr),
        .arvalid (axi_arvalid),
        .arready (axi_arready),
        .rdata   (axi_rdata),
        .rresp   (axi_rresp),
        .rvalid  (axi_rvalid),
        .rready  (axi_rready)
    );

    // ==========================================================
    //  AXI4-Lite Interconnect
    // ==========================================================
    axi_interconnect u_axi_interconnect (
        .clk    (clk),
        .reset  (reset),
        .slave_awaddr  (axi_awaddr),
        .slave_awvalid (axi_awvalid),
        .slave_awready (axi_awready),
        .slave_wdata   (axi_wdata),
        .slave_wstrb   (axi_wstrb),
        .slave_wvalid  (axi_wvalid),
        .slave_wready  (axi_wready),
        .slave_bresp   (axi_bresp),
        .slave_bvalid  (axi_bvalid),
        .slave_bready  (axi_bready),
        .slave_araddr  (axi_araddr),
        .slave_arvalid (axi_arvalid),
        .slave_arready (axi_arready),
        .slave_rdata   (axi_rdata),
        .slave_rresp   (axi_rresp),
        .slave_rvalid  (axi_rvalid),
        .slave_rready  (axi_rready),

        .pwm_awaddr    (pwm_awaddr),
        .pwm_awvalid   (pwm_awvalid),
        .pwm_awready   (pwm_awready),
        .pwm_wdata     (pwm_wdata),
        .pwm_wstrb     (pwm_wstrb),
        .pwm_wvalid    (pwm_wvalid),
        .pwm_wready    (pwm_wready),
        .pwm_bresp     (pwm_bresp),
        .pwm_bvalid    (pwm_bvalid),
        .pwm_bready    (pwm_bready),
        .pwm_araddr    (pwm_araddr),
        .pwm_arvalid   (pwm_arvalid),
        .pwm_arready   (pwm_arready),
        .pwm_rdata     (pwm_rdata),
        .pwm_rresp     (pwm_rresp),
        .pwm_rvalid    (pwm_rvalid),
        .pwm_rready    (pwm_rready)
    );

    // ==========================================================
    //  PWM Peripheral
    // ==========================================================
    pwm_peripheral u_pwm_peripheral (
        .clk     (clk),
        .reset   (reset),
        .awaddr  (pwm_awaddr),
        .awvalid (pwm_awvalid),
        .awready (pwm_awready),
        .wdata   (pwm_wdata),
        .wstrb   (pwm_wstrb),
        .wvalid  (pwm_wvalid),
        .wready  (pwm_wready),
        .bresp   (pwm_bresp),
        .bvalid  (pwm_bvalid),
        .bready  (pwm_bready),
        .araddr  (pwm_araddr),
        .arvalid (pwm_arvalid),
        .arready (pwm_arready),
        .rdata   (pwm_rdata),
        .rresp   (pwm_rresp),
        .rvalid  (pwm_rvalid),
        .rready  (pwm_rready),
        .pwm_out (pwm_out)
    );

endmodule
