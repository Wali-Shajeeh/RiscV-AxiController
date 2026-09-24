module updated_top_module2 #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 9600
)(
    input  logic clk,
    input  logic reset,
    output logic pwm_out,
    output logic uart_tx,
    input  logic uart_rx,
    output logic [31:0] gpio_out,
    input  logic [31:0] gpio_in,
    output logic        timer_overflow
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

    
    logic [31:0] axi_awaddr;
    logic         axi_awvalid;
    logic         axi_awready;
    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic         axi_wvalid;
    logic         axi_wready;
    logic [1:0]  axi_bresp;
    logic         axi_bvalid;
    logic         axi_bready;
    logic [31:0] axi_araddr;
    logic         axi_arvalid;
    logic         axi_arready;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic         axi_rvalid;
    logic         axi_rready;

    // >>> NEW: Interconnect <-> PWM wires
    logic [31:0] pwm_awaddr_w;
    logic         pwm_awvalid_w;
    logic         pwm_awready_w;
    logic [31:0] pwm_wdata_w;
    logic [3:0]  pwm_wstrb_w;
    logic         pwm_wvalid_w;
    logic         pwm_wready_w;
    logic [1:0]  pwm_bresp_w;
    logic         pwm_bvalid_w;
    logic         pwm_bready_w;
    logic [31:0] pwm_araddr_w;
    logic         pwm_arvalid_w;
    logic         pwm_arready_w;
    logic [31:0] pwm_rdata_w;
    logic [1:0]  pwm_rresp_w;
    logic         pwm_rvalid_w;
    logic         pwm_rready_w;
    // <<< NEW
    
    // >>> Interconnect <-> UART wires
    logic [31:0] uart_awaddr_w;
    logic        uart_awvalid_w;
    logic        uart_awready_w;
    logic [31:0] uart_wdata_w;
    logic [3:0]  uart_wstrb_w;
    logic        uart_wvalid_w;
    logic        uart_wready_w;
    logic [1:0]  uart_bresp_w;
    logic        uart_bvalid_w;
    logic        uart_bready_w;
    logic [31:0] uart_araddr_w;
    logic        uart_arvalid_w;
    logic        uart_arready_w;
    logic [31:0] uart_rdata_w;
    logic [1:0]  uart_rresp_w;
    logic        uart_rvalid_w;
    logic        uart_rready_w;
    // <<< UART wires
    
    // >>> Interconnect <-> GPIO wires
    logic [31:0] gpio_awaddr_w;
    logic        gpio_awvalid_w;
    logic        gpio_awready_w;
    logic [31:0] gpio_wdata_w;
    logic [3:0]  gpio_wstrb_w;
    logic        gpio_wvalid_w;
    logic        gpio_wready_w;
    logic [1:0]  gpio_bresp_w;
    logic        gpio_bvalid_w;
    logic        gpio_bready_w;
    logic [31:0] gpio_araddr_w;
    logic        gpio_arvalid_w;
    logic        gpio_arready_w;
    logic [31:0] gpio_rdata_w;
    logic [1:0]  gpio_rresp_w;
    logic        gpio_rvalid_w;
    logic        gpio_rready_w;
    // <<< GPIO wires
    
    // >>> Interconnect <-> Timer wires
    logic [31:0] timer_awaddr_w;
    logic        timer_awvalid_w;
    logic        timer_awready_w;
    logic [31:0] timer_wdata_w;
    logic [3:0]  timer_wstrb_w;
    logic        timer_wvalid_w;
    logic        timer_wready_w;
    logic [1:0]  timer_bresp_w;
    logic        timer_bvalid_w;
    logic        timer_bready_w;
    logic [31:0] timer_araddr_w;
    logic        timer_arvalid_w;
    logic        timer_arready_w;
    logic [31:0] timer_rdata_w;
    logic [1:0]  timer_rresp_w;
    logic        timer_rvalid_w;
    logic        timer_rready_w;
    // <<< Timer wires
    

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

    // >>> NEW: PWM Peripheral instantiate kiya
    pwm_peripheral u_pwm_peripheral (
        .clk     (clk),
        .reset   (reset),

        .awaddr  (pwm_awaddr_w),
        .awvalid (pwm_awvalid_w),
        .awready (pwm_awready_w),
        .wdata   (pwm_wdata_w),
        .wstrb   (pwm_wstrb_w),
        .wvalid  (pwm_wvalid_w),
        .wready  (pwm_wready_w),
        .bresp   (pwm_bresp_w),
        .bvalid  (pwm_bvalid_w),
        .bready  (pwm_bready_w),
        .araddr  (pwm_araddr_w),
        .arvalid (pwm_arvalid_w),
        .arready (pwm_arready_w),
        .rdata   (pwm_rdata_w),
        .rresp   (pwm_rresp_w),
        .rvalid  (pwm_rvalid_w),
        .rready  (pwm_rready_w),

        .pwm_out (pwm_out)
    );
    // <<< NEW

    // >>> Instantiate UART Peripheral
    uart_peripheral #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_peripheral (
        .clk      (clk),
        .reset    (reset),

        .awaddr   (uart_awaddr_w),
        .awvalid  (uart_awvalid_w),
        .awready  (uart_awready_w),
        .wdata    (uart_wdata_w),
        .wstrb    (uart_wstrb_w),
        .wvalid   (uart_wvalid_w),
        .wready   (uart_wready_w),
        .bresp    (uart_bresp_w),
        .bvalid   (uart_bvalid_w),
        .bready   (uart_bready_w),
        .araddr   (uart_araddr_w),
        .arvalid  (uart_arvalid_w),
        .arready  (uart_arready_w),
        .rdata    (uart_rdata_w),
        .rresp    (uart_rresp_w),
        .rvalid   (uart_rvalid_w),
        .rready   (uart_rready_w),

        .tx       (uart_tx),
        .rx       (uart_rx),
        .rx_ready (),
        .rx_data  ()
    );
    // <<<

    // >>> Instantiate GPIO Peripheral
    gpio_peripheral u_gpio_peripheral (
        .clk      (clk),
        .reset    (reset),

        .awaddr   (gpio_awaddr_w),
        .awvalid  (gpio_awvalid_w),
        .awready  (gpio_awready_w),
        .wdata    (gpio_wdata_w),
        .wstrb    (gpio_wstrb_w),
        .wvalid   (gpio_wvalid_w),
        .wready   (gpio_wready_w),
        .bresp    (gpio_bresp_w),
        .bvalid   (gpio_bvalid_w),
        .bready   (gpio_bready_w),
        .araddr   (gpio_araddr_w),
        .arvalid  (gpio_arvalid_w),
        .arready  (gpio_arready_w),
        .rdata    (gpio_rdata_w),
        .rresp    (gpio_rresp_w),
        .rvalid   (gpio_rvalid_w),
        .rready   (gpio_rready_w),

        .gpio_out (gpio_out),
        .gpio_in  (gpio_in)
    );
    // <<< GPIO

    // >>> Instantiate Timer Peripheral
    timer_peripheral u_timer_peripheral (
        .clk            (clk),
        .reset          (reset),

        .awaddr         (timer_awaddr_w),
        .awvalid        (timer_awvalid_w),
        .awready        (timer_awready_w),
        .wdata          (timer_wdata_w),
        .wstrb          (timer_wstrb_w),
        .wvalid         (timer_wvalid_w),
        .wready         (timer_wready_w),
        .bresp          (timer_bresp_w),
        .bvalid         (timer_bvalid_w),
        .bready         (timer_bready_w),
        .araddr         (timer_araddr_w),
        .arvalid        (timer_arvalid_w),
        .arready        (timer_arready_w),
        .rdata          (timer_rdata_w),
        .rresp          (timer_rresp_w),
        .rvalid         (timer_rvalid_w),
        .rready         (timer_rready_w),

        .timer_overflow (timer_overflow)
    );
    // <<< Timer

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

        // ---------------- PWM ----------------
        .pwm_awaddr    (pwm_awaddr_w),
        .pwm_awvalid   (pwm_awvalid_w),
        .pwm_awready   (pwm_awready_w),
        .pwm_wdata     (pwm_wdata_w),
        .pwm_wstrb     (pwm_wstrb_w),
        .pwm_wvalid    (pwm_wvalid_w),
        .pwm_wready    (pwm_wready_w),
        .pwm_bresp     (pwm_bresp_w),
        .pwm_bvalid    (pwm_bvalid_w),
        .pwm_bready    (pwm_bready_w),
        .pwm_araddr    (pwm_araddr_w),
        .pwm_arvalid   (pwm_arvalid_w),
        .pwm_arready   (pwm_arready_w),
        .pwm_rdata     (pwm_rdata_w),
        .pwm_rresp     (pwm_rresp_w),
        .pwm_rvalid    (pwm_rvalid_w),
        .pwm_rready    (pwm_rready_w),

        // ---------------- Timer (connected) ----------------
        .timer_awaddr  (timer_awaddr_w),
        .timer_awvalid (timer_awvalid_w),
        .timer_awready (timer_awready_w),
        .timer_wdata   (timer_wdata_w),
        .timer_wstrb   (timer_wstrb_w),
        .timer_wvalid  (timer_wvalid_w),
        .timer_wready  (timer_wready_w),
        .timer_bresp   (timer_bresp_w),
        .timer_bvalid  (timer_bvalid_w),
        .timer_bready  (timer_bready_w),
        .timer_araddr  (timer_araddr_w),
        .timer_arvalid (timer_arvalid_w),
        .timer_arready (timer_arready_w),
        .timer_rdata   (timer_rdata_w),
        .timer_rresp   (timer_rresp_w),
        .timer_rvalid  (timer_rvalid_w),
        .timer_rready  (timer_rready_w),

        // ---------------- GPIO (connected) ----------------
        .gpio_awaddr   (gpio_awaddr_w),
        .gpio_awvalid  (gpio_awvalid_w),
        .gpio_awready  (gpio_awready_w),
        .gpio_wdata    (gpio_wdata_w),
        .gpio_wstrb    (gpio_wstrb_w),
        .gpio_wvalid   (gpio_wvalid_w),
        .gpio_wready   (gpio_wready_w),
        .gpio_bresp    (gpio_bresp_w),
        .gpio_bvalid   (gpio_bvalid_w),
        .gpio_bready   (gpio_bready_w),
        .gpio_araddr   (gpio_araddr_w),
        .gpio_arvalid  (gpio_arvalid_w),
        .gpio_arready  (gpio_arready_w),
        .gpio_rdata    (gpio_rdata_w),
        .gpio_rresp    (gpio_rresp_w),
        .gpio_rvalid   (gpio_rvalid_w),
        .gpio_rready   (gpio_rready_w),

        // ---------------- UART (connected) ----------------
        .uart_awaddr   (uart_awaddr_w),
        .uart_awvalid  (uart_awvalid_w),
        .uart_awready  (uart_awready_w),
        .uart_wdata    (uart_wdata_w),
        .uart_wstrb    (uart_wstrb_w),
        .uart_wvalid   (uart_wvalid_w),
        .uart_wready   (uart_wready_w),
        .uart_bresp    (uart_bresp_w),
        .uart_bvalid   (uart_bvalid_w),
        .uart_bready   (uart_bready_w),
        .uart_araddr   (uart_araddr_w),
        .uart_arvalid  (uart_arvalid_w),
        .uart_arready  (uart_arready_w),
        .uart_rdata    (uart_rdata_w),
        .uart_rresp    (uart_rresp_w),
        .uart_rvalid   (uart_rvalid_w),
        .uart_rready   (uart_rready_w)
    );
    

    assign combined_read_data = is_peripheral_access ? axi_read_data : mem_read_data;
    

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