module decoder (
    input  logic [6:0] opcode,

    output logic        reg_write,      // register file write enable
    output logic        mem_read,       // data memory read enable
    output logic        mem_write,      // data memory write enable
    output logic        mem_to_reg,     // writeback source: 0=ALU result, 1=memory data
    output logic        alu_src,        // ALU operand B source: 0=register, 1=immediate
    output logic        branch,         // branch instruction flag
    output logic        jump,           // jal/jalr flag
    output logic [1:0]  alu_op,         // high-level ALU operation hint (for ALU control)
    output logic         pc_src_jalr,   // 1 if jalr (target = rs1+imm), used in PC mux logic
    output logic [1:0]   alu_src_a
);

    always_comb begin
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        alu_src     = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        alu_op      = 2'b00;
        pc_src_jalr = 1'b0;
        alu_src_a   = 2'b00;

        case (opcode)
		  //r-type
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;      // operand B = register (rs2)
                alu_op    = 2'b10;     // "R-type" hint → ALU control decides exact op via funct3/funct7
            end
             //i-type
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;      // operand B = immediate
                alu_op    = 2'b11;     // "I-type ALU" hint → ALU control decides exact op via funct3
            end

            // ---------------------------------------------------
            // Load: lw, lb, lh, lbu, lhu
            // ---------------------------------------------------
            7'b0000011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;     // operand B = immediate (offset)
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;     // writeback source = memory data
                alu_op     = 2'b00;    // ALU does ADD (address calculation)
            end

            // ---------------------------------------------------
            // Store: sw, sb, sh
            // ---------------------------------------------------
            7'b0100011: begin
                alu_src   = 1'b1;      // operand B = immediate (offset)
                mem_write = 1'b1;
                alu_op    = 2'b00;     // ALU does ADD (address calculation)
            end

            // ---------------------------------------------------
            // Branch: beq, bne, blt, bge, bltu, bgeu
            // ---------------------------------------------------
            7'b1100011: begin
                branch = 1'b1;
                alu_src = 1'b0;        // operand B = register (rs2), for comparison
                alu_op  = 2'b01;       // ALU does SUB (comparison via zero_flag) or SLT
            end

            // ---------------------------------------------------
            // JAL: unconditional jump, link
            // ---------------------------------------------------
            7'b1101111: begin
                reg_write = 1'b1;      // rd = PC+4
                jump      = 1'b1;
                alu_src_a = 2'b01;
            end

            // ---------------------------------------------------
            // JALR: jump register, link
            // ---------------------------------------------------
            7'b1100111: begin
                reg_write   = 1'b1;    // rd = PC+4
                alu_src     = 1'b1;    // operand B = immediate
                jump        = 1'b1;
                pc_src_jalr = 1'b1;    // target = rs1 + imm
                alu_op      = 2'b00;   // ALU does ADD (rs1 + imm)
            end

            // ---------------------------------------------------
            // LUI: load upper immediate
            // ---------------------------------------------------
            7'b0110111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;     // pass immediate through (treated as ADD with 0, or direct mux)
                alu_src_a = 2'b10;
            end

            // ---------------------------------------------------
            // AUIPC: add upper immediate to PC
            // ---------------------------------------------------
            7'b0010111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;     // ALU does ADD (PC + imm) — needs PC as operand A
                alu_src_a = 2'b01;
            end

            default: begin
                // Unknown/unsupported opcode → sab signals off (safe/no-op)
            end

        endcase
    end

endmodule
