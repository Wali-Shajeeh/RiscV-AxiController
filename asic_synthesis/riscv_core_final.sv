module riscv_core_final (
    input  logic clk,
    input  logic reset
);
    logic [31:0] pc_current, pc_next;
    logic [31:0] instruction;
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] read_data1, read_data2;
    logic [31:0] imm;
    logic [31:0] write_data_reg;    // register file ko wapis jaane wala data
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;
    logic         zero_flag;
    logic [3:0]  alu_control_sig;
    logic [31:0] mem_read_data;
    //control signals
    logic        reg_write, mem_read, mem_write, mem_to_reg;
    logic        alu_src, branch, jump, pc_src_jalr;
    logic [1:0]  alu_op;
    logic [31:0] pc_plus4;

   
    logic         is_peripheral_access;
    logic [31:0] axi_read_data;
    logic         axi_busy;
    logic         stall;
    logic [31:0] combined_read_data;
    logic         reg_write_final;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];
    assign pc_plus4 = pc_current + 32'd4;

  
    assign is_peripheral_access = (alu_result >= 32'h4000_0000);
    assign stall = axi_busy;


    pc_reg u_pc_reg (
        .clk      (clk),
        .reset    (reset),
        .pc_next  (stall ? pc_current : pc_next),
        .pc_out   (pc_current)
    );

    instr_mem u_instr_mem (
        .clk         (clk),
        .addr        (pc_current),
        .instruction (instruction)
    );

    decoder u_control_unit (
        .opcode      (opcode),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_to_reg  (mem_to_reg),
        .alu_src     (alu_src),
        .branch      (branch),
        .jump        (jump),
        .alu_op      (alu_op),
        .pc_src_jalr (pc_src_jalr)
    );

    assign reg_write_final = reg_write & ~stall;

    reg_file u_reg_file (
        .clk         (clk),
        .reset       (reset),
        .rs1         (rs1),
        .rs2         (rs2),
        .rd          (rd),
        .write_data  (write_data_reg),
        .reg_write   (reg_write_final),
        .read_data1  (read_data1),
        .read_data2  (read_data2)
    );

    imm_gen u_imm_gen (
        .instruction (instruction),
        .imm_out     (imm)
    );

    alu_control u_alu_control (
        .alu_op      (alu_op),
        .funct3      (funct3),
        .funct7      (funct7),
        .alu_control (alu_control_sig)
    );

    assign alu_operand_b = (alu_src) ? imm : read_data2;

    alu u_alu (
        .operand_a   (read_data1),
        .operand_b   (alu_operand_b),
        .alu_control (alu_control_sig),
        .alu_result  (alu_result),
        .zero_flag   (zero_flag)
    );

    data_mem u_data_mem (
        .clk         (clk),
        .addr        (alu_result),      // load/store address = base + offset
        .write_data  (read_data2),      // store ke liye rs2 ki value jaati hai
        .mem_read    (mem_read  & ~is_peripheral_access),
        .mem_write   (mem_write & ~is_peripheral_access),
        .read_data   (mem_read_data)
    );


    axi_adapter u_axi_adapter (
        .clk         (clk),
        .reset       (reset),

        .addr        (alu_result),
        .write_data  (read_data2),
        .read_req    (mem_read  & is_peripheral_access),
        .write_req   (mem_write & is_peripheral_access),
        .read_data   (axi_read_data),
        .busy        (axi_busy),

        // In signals ko interconnect se connect karna hoga (Phase 3 mein)
        .awaddr  (),
        .awvalid (),
        .awready (1'b0),   // temporary tie-off, jab tak interconnect nahi banta
        .wdata   (),
        .wstrb   (),
        .wvalid  (),
        .wready  (1'b0),
        .bresp   (2'b00),
        .bvalid  (1'b0),
        .bready  (),
        .araddr  (),
        .arvalid (),
        .arready (1'b0),
        .rdata   (32'b0),
        .rresp   (2'b00),
        .rvalid  (1'b0),
        .rready  ()
    );

    assign combined_read_data = is_peripheral_access ? axi_read_data : mem_read_data;
    // <<< NEW

    // -----------------------------------------------------------
    // 10. Writeback Mux — register file mein kya likhna hai
    //     Priority: jump (PC+4)  >  mem_to_reg (load data)  >  ALU result
    // -----------------------------------------------------------
    always_comb begin
        if (jump)
            write_data_reg = pc_plus4;       // jal/jalr: rd = return address
        else if (mem_to_reg)
            write_data_reg = combined_read_data;
        else
            write_data_reg = alu_result;     // R-type/I-type: rd = ALU result
    end

    pc_control u_pc_control (
        .pc_current   (pc_current),
        .imm          (imm),
        .rs1_data     (read_data1),
        .branch       (branch),
        .jump         (jump),
        .pc_src_jalr  (pc_src_jalr),
        .zero_flag    (zero_flag),
        .funct3       (funct3),
        .alu_lt_result(alu_result[0]),   // SLT/SLTU result ka LSB hi 0/1 flag hai
        .pc_next      (pc_next)
    );

endmodule
