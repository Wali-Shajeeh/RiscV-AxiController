// =============================================================
// controller_fsm.sv — Multicycle FSM Controller for RV32I
// Replaces: decoder.sv + pc_control.sv from single-cycle design
// =============================================================
// State flow per instruction type:
//   R-type / I-type / LUI / AUIPC : FETCH → DECODE → EXECUTE → WRITEBACK  (4 cycles)
//   Load                          : FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK  (5 cycles)
//   Store                         : FETCH → DECODE → EXECUTE → MEMORY  (4 cycles)
//   Branch                        : FETCH → DECODE → EXECUTE  (3 cycles)
//   JAL / JALR                    : FETCH → DECODE → EXECUTE  (3 cycles, wr in EXECUTE)
// =============================================================

module controller_fsm (
    input  logic        clk,
    input  logic        reset,
    input  logic [6:0]  opcode,         // from IR
    input  logic [2:0]  funct3,         // from IR (branch type)
    input  logic        zero_flag,      // from ALU (beq/bne)
    input  logic        alu_lt_result,  // from ALU result[0] (blt/bge/bltu/bgeu)
    input  logic        mem_ready,      // from memory/AXI subsystem

    output logic        ir_write,       // latch instruction into IR
    output logic        pc_write,       // enable PC register update
    output logic [1:0]  pc_src,         // 00=PC+4, 01=branch/JAL, 10=JALR
    output logic        reg_write,      // register file write enable
    output logic [1:0]  reg_write_src,  // 00=ALUOut, 01=MDR, 10=PC+4(link)
    output logic        alu_src_b,      // 0=B_reg(rs2), 1=imm
    output logic [1:0]  alu_src_a,      // 00=A_reg(rs1), 01=pc_saved, 10=zero
    output logic [1:0]  alu_op,         // ALU operation hint for alu_control
    output logic        mem_read,       // data memory read enable
    output logic        mem_write       // data memory write enable
);

    // -----------------------------------------------------------
    // State encoding
    // -----------------------------------------------------------
    typedef enum logic [2:0] {
        S_FETCH     = 3'd0,
        S_DECODE    = 3'd1,
        S_EXECUTE   = 3'd2,
        S_MEMORY    = 3'd3,
        S_WRITEBACK = 3'd4
    } state_t;

    state_t state, next_state;

    // -----------------------------------------------------------
    // Opcode decode helpers (from IR, stable after FETCH)
    // -----------------------------------------------------------
    logic is_rtype, is_itype_alu, is_load, is_store, is_branch;
    logic is_jal, is_jalr, is_lui, is_auipc;

    assign is_rtype     = (opcode == 7'b0110011);
    assign is_itype_alu = (opcode == 7'b0010011);
    assign is_load      = (opcode == 7'b0000011);
    assign is_store     = (opcode == 7'b0100011);
    assign is_branch    = (opcode == 7'b1100011);
    assign is_jal       = (opcode == 7'b1101111);
    assign is_jalr      = (opcode == 7'b1100111);
    assign is_lui       = (opcode == 7'b0110111);
    assign is_auipc     = (opcode == 7'b0010111);

    // -----------------------------------------------------------
    // Branch condition evaluation (same logic as old pc_control)
    // -----------------------------------------------------------
    logic branch_taken;

    always_comb begin
        case (funct3)
            3'b000:  branch_taken = zero_flag;          // beq  (equal)
            3'b001:  branch_taken = ~zero_flag;         // bne  (not equal)
            3'b100:  branch_taken = alu_lt_result;      // blt  (less than, signed)
            3'b101:  branch_taken = ~alu_lt_result;     // bge  (greater/equal, signed)
            3'b110:  branch_taken = alu_lt_result;      // bltu (less than, unsigned)
            3'b111:  branch_taken = ~alu_lt_result;     // bgeu (greater/equal, unsigned)
            default: branch_taken = 1'b0;
        endcase
    end

    // -----------------------------------------------------------
    // State register
    // -----------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_FETCH;
        else
            state <= next_state;
    end

    // -----------------------------------------------------------
    // Next-state logic
    // -----------------------------------------------------------
    always_comb begin
        next_state = state;     // default: hold

        case (state)
            S_FETCH:
                next_state = S_DECODE;

            S_DECODE:
                next_state = S_EXECUTE;

            S_EXECUTE: begin
                if (is_load || is_store)
                    next_state = S_MEMORY;       // need one more cycle for data mem
                else if (is_branch || is_jal || is_jalr)
                    next_state = S_FETCH;        // done — PC updated in this state
                else
                    next_state = S_WRITEBACK;    // R/I/LUI/AUIPC → write rd
            end

            S_MEMORY: begin
                if (!mem_ready) begin
                    next_state = S_MEMORY;       // Wait for AXI/memory
                end else if (is_load) begin
                    next_state = S_WRITEBACK;    // load: need to write MDR → rd
                end else begin
                    next_state = S_FETCH;        // store: done after mem write
                end
            end

            S_WRITEBACK:
                next_state = S_FETCH;            // always go fetch next instruction

            default:
                next_state = S_FETCH;
        endcase
    end

    // -----------------------------------------------------------
    // Output logic (Mealy — depends on state + opcode)
    // -----------------------------------------------------------
    always_comb begin
        // Safe defaults — everything off
        ir_write      = 1'b0;
        pc_write      = 1'b0;
        pc_src        = 2'b00;
        reg_write     = 1'b0;
        reg_write_src = 2'b00;
        alu_src_b     = 1'b0;
        alu_src_a     = 2'b00;
        alu_op        = 2'b00;
        mem_read      = 1'b0;
        mem_write     = 1'b0;

        case (state)

            // ==============================================
            // FETCH: latch instruction, advance PC to PC+4
            // ==============================================
            S_FETCH: begin
                ir_write = 1'b1;        // save instruction → IR
                pc_write = 1'b1;        // PC <= PC + 4
                pc_src   = 2'b00;       // source = PC + 4
            end

            // ==============================================
            // DECODE: register file reads happen via rs1/rs2
            //         A, B registers latch automatically
            //         imm_gen decodes immediate from IR
            // ==============================================
            S_DECODE: begin
                // No special control — A/B latch every cycle,
                // imm_gen is combinational from IR
            end

            // ==============================================
            // EXECUTE: ALU operation + branch/jump resolution
            // ==============================================
            S_EXECUTE: begin

                if (is_rtype) begin
                    // ALU: A op B
                    alu_src_a = 2'b00;      // A (rs1)
                    alu_src_b = 1'b0;       // B (rs2)
                    alu_op    = 2'b10;      // R-type decode
                end

                else if (is_itype_alu) begin
                    // ALU: A op imm
                    alu_src_a = 2'b00;      // A (rs1)
                    alu_src_b = 1'b1;       // immediate
                    alu_op    = 2'b11;      // I-type ALU decode
                end

                else if (is_load || is_store) begin
                    // ALU: base + offset → address
                    alu_src_a = 2'b00;      // A (rs1 = base addr)
                    alu_src_b = 1'b1;       // immediate (offset)
                    alu_op    = 2'b00;      // ADD
                end

                else if (is_branch) begin
                    // ALU: compare A vs B
                    alu_src_a = 2'b00;      // A (rs1)
                    alu_src_b = 1'b0;       // B (rs2)
                    alu_op    = 2'b01;      // SUB / SLT for comparison
                    // Conditionally update PC
                    if (branch_taken) begin
                        pc_write = 1'b1;
                        pc_src   = 2'b01;   // pc_saved + imm
                    end
                end

                else if (is_jal) begin
                    // Jump to pc_saved + imm, save return address
                    pc_write      = 1'b1;
                    pc_src        = 2'b01;      // pc_saved + imm
                    reg_write     = 1'b1;       // rd = return address
                    reg_write_src = 2'b10;      // pc_saved + 4
                end

                else if (is_jalr) begin
                    // ALU: A + imm (for target calculation)
                    alu_src_a     = 2'b00;      // A (rs1)
                    alu_src_b     = 1'b1;       // immediate
                    alu_op        = 2'b00;      // ADD
                    // Jump to (A + imm) & ~1
                    pc_write      = 1'b1;
                    pc_src        = 2'b10;      // JALR target
                    reg_write     = 1'b1;       // rd = return address
                    reg_write_src = 2'b10;      // pc_saved + 4
                end

                else if (is_lui) begin
                    // ALU: 0 + imm = imm
                    alu_src_a = 2'b10;      // zero
                    alu_src_b = 1'b1;       // immediate
                    alu_op    = 2'b00;      // ADD (0 + imm)
                end

                else if (is_auipc) begin
                    // ALU: PC + imm
                    alu_src_a = 2'b01;      // pc_saved
                    alu_src_b = 1'b1;       // immediate
                    alu_op    = 2'b00;      // ADD
                end

            end // S_EXECUTE

            // ==============================================
            // MEMORY: data memory read (load) or write (store)
            // ==============================================
            S_MEMORY: begin
                if (is_load || is_store) begin
                    // Keep ALU computing base + offset so ALUOut stays stable
                    alu_src_a = 2'b00;      // A (rs1)
                    alu_src_b = 1'b1;       // immediate
                    alu_op    = 2'b00;      // ADD
                end
                
                if (is_load)
                    mem_read = 1'b1;
                else if (is_store)
                    mem_write = 1'b1;
            end

            // ==============================================
            // WRITEBACK: write result to register file
            // ==============================================
            S_WRITEBACK: begin
                // Keep ALU stable for R-type, I-type, LUI, AUIPC (though ALUOut is already captured, it's safer)
                if (is_rtype) begin
                    alu_src_a = 2'b00; alu_src_b = 1'b0; alu_op = 2'b10;
                end else if (is_itype_alu) begin
                    alu_src_a = 2'b00; alu_src_b = 1'b1; alu_op = 2'b11;
                end else if (is_lui) begin
                    alu_src_a = 2'b10; alu_src_b = 1'b1; alu_op = 2'b00;
                end else if (is_auipc) begin
                    alu_src_a = 2'b01; alu_src_b = 1'b1; alu_op = 2'b00;
                end

                reg_write = 1'b1;
                if (is_load)
                    reg_write_src = 2'b01;      // MDR (memory data)
                else
                    reg_write_src = 2'b00;      // ALUOut (R/I/LUI/AUIPC)
            end

            default: ;

        endcase
    end

endmodule
