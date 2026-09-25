module pc_control (
    input  logic [31:0] pc_current,     // current PC value
    input  logic [31:0] imm,            // immediate generator se aaya immediate (B-type/J-type)
    input  logic [31:0] rs1_data,       // register file se rs1 value (jalr ke liye)
    input  logic         branch,         // control unit se: 1 = branch instruction hai
    input  logic         jump,           // control unit se: 1 = jal/jalr hai
    input  logic         pc_src_jalr,    // control unit se: 1 = jalr (target = rs1+imm)
    input  logic         zero_flag,      // ALU se aaya (branch condition ke liye)
    input  logic [2:0]  funct3,         // branch type differentiate karne ke liye (beq/bne/blt/etc.)
    input  logic         alu_lt_result,  // ALU se SLT/SLTU result (blt/bge/bltu/bgeu ke liye)

    output logic [31:0] pc_next         // agla PC value
);

    logic branch_taken;
    logic [31:0] pc_plus4;
    logic [31:0] pc_plus_imm;     // branch/jal target = PC + imm
    logic [31:0] jalr_target;     // jalr target = rs1 + imm

    assign pc_plus4    = pc_current + 32'd4;
    assign pc_plus_imm = pc_current + imm;
    assign jalr_target = (rs1_data + imm) & ~32'b1;   // LSB clear (RISC-V spec requirement)

    // -----------------------------------------------------------
    // Branch condition evaluate karna (funct3 ke hisaab se)
    // -----------------------------------------------------------
    always_comb begin
        case (funct3)
            3'b000:  branch_taken = branch &  zero_flag;        // beq  (equal)
            3'b001:  branch_taken = branch & ~zero_flag;        // bne  (not equal)
            3'b100:  branch_taken = branch &  alu_lt_result;    // blt  (less than, signed)
            3'b101:  branch_taken = branch & ~alu_lt_result;    // bge  (greater/equal, signed)
            3'b110:  branch_taken = branch &  alu_lt_result;    // bltu (less than, unsigned)
            3'b111:  branch_taken = branch & ~alu_lt_result;    // bgeu (greater/equal, unsigned)
            default: branch_taken = 1'b0;
        endcase
    end

    // -----------------------------------------------------------
    // Final PC selection
    // -----------------------------------------------------------
    always_comb begin
        if (jump && pc_src_jalr)
            pc_next = jalr_target;        // jalr: target = rs1 + imm
        else if (jump)
            pc_next = pc_plus_imm;        // jal: target = PC + imm
        else if (branch_taken)
            pc_next = pc_plus_imm;        // branch taken: target = PC + imm
        else
            pc_next = pc_plus4;           // normal sequential execution
    end

endmodule