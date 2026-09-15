module alu_control (
    input  logic [1:0] alu_op,      // Control Unit se aaya hint
    input  logic [2:0] funct3,      // instruction[14:12]
    input  logic [6:0] funct7,      // instruction[31:25]

    output logic [3:0] alu_control  // ALU module ko jaane wala final code
);

    always_comb begin
        case (alu_op)

            // -------------------------------------------------
            // alu_op = 00 → ADD (Load, Store, JALR, LUI, AUIPC)
            // -------------------------------------------------
            2'b00: alu_control = 4'b0000;   // ADD

            // -------------------------------------------------
            // alu_op = 01 → Branch (SUB for comparison via zero_flag,
            //                        or SLT/SLTU for blt/bge type)
            // -------------------------------------------------
            2'b01: begin
                case (funct3)
                    3'b000: alu_control = 4'b0001;  // beq  → SUB (zero_flag check)
                    3'b001: alu_control = 4'b0001;  // bne  → SUB (zero_flag check)
                    3'b100: alu_control = 4'b1000;  // blt  → SLT (signed)
                    3'b101: alu_control = 4'b1000;  // bge  → SLT (signed)
                    3'b110: alu_control = 4'b1001;  // bltu → SLTU (unsigned)
                    3'b111: alu_control = 4'b1001;  // bgeu → SLTU (unsigned)
                    default: alu_control = 4'b0001;
                endcase
            end

            // -------------------------------------------------
            // alu_op = 10 → R-type (funct3 + funct7 decide exact op)
            // -------------------------------------------------
            2'b10: begin
                case (funct3)
                    3'b000: alu_control = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000; // sub : add
                    3'b001: alu_control = 4'b0101;  // sll
                    3'b010: alu_control = 4'b1000;  // slt
                    3'b011: alu_control = 4'b1001;  // sltu
                    3'b100: alu_control = 4'b0100;  // xor
                    3'b101: alu_control = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // sra : srl
                    3'b110: alu_control = 4'b0011;  // or
                    3'b111: alu_control = 4'b0010;  // and
                    default: alu_control = 4'b0000;
                endcase
            end

            // -------------------------------------------------
            // alu_op = 11 → I-type ALU (addi, andi, ori, slli, srli, srai...)
            // Note: funct7 sirf slli/srli/srai mein relevant hai (shift amount ke encoding mein)
            // -------------------------------------------------
            2'b11: begin
                case (funct3)
                    3'b000: alu_control = 4'b0000;  // addi
                    3'b001: alu_control = 4'b0101;  // slli
                    3'b010: alu_control = 4'b1000;  // slti
                    3'b011: alu_control = 4'b1001;  // sltiu
                    3'b100: alu_control = 4'b0100;  // xori
                    3'b101: alu_control = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // srai : srli
                    3'b110: alu_control = 4'b0011;  // ori
                    3'b111: alu_control = 4'b0010;  // andi
                    default: alu_control = 4'b0000;
                endcase
            end

            default: alu_control = 4'b0000;

        endcase
    end

endmodule
