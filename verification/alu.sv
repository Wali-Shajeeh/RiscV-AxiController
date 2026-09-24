module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_control,   // decides which operation
    output logic [31:0] alu_result,
    output logic         zero_flag      // 1 if result == 0 (branches ke liye)
);

    always_comb begin
        case (alu_control)
            4'b0000: alu_result = operand_a + operand_b;                     // ADD
            4'b0001: alu_result = operand_a - operand_b;                     // SUB
            4'b0010: alu_result = operand_a & operand_b;                     // AND
            4'b0011: alu_result = operand_a | operand_b;                     // OR
            4'b0100: alu_result = operand_a ^ operand_b;                     // XOR
            4'b0101: alu_result = operand_a << operand_b[4:0];               // SLL (shift left logical)
            4'b0110: alu_result = operand_a >> operand_b[4:0];               // SRL (shift right logical)
            4'b0111: alu_result = $signed(operand_a) >>> operand_b[4:0];     // SRA (shift right arithmetic)
            4'b1000: alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'b1 : 32'b0;  // SLT (signed)
            4'b1001: alu_result = (operand_a < operand_b) ? 32'b1 : 32'b0;   // SLTU (unsigned)
            default: alu_result = 32'b0;
        endcase
    end

    assign zero_flag = (alu_result == 32'b0);

endmodule