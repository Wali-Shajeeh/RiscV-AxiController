// ============================================================================
//  GPIO Peripheral — AXI4-Lite Slave
// ============================================================================
//  Address Map (base = 0x4002_0000):
//    0x00  GPIO_DIR    — Direction register  (0 = input, 1 = output per bit)
//    0x04  GPIO_OUT    — Output data register (drives gpio_out pins)
//    0x08  GPIO_IN     — Input data register  (read-only, sampled from gpio_in)
//
//  AXI4-Lite Write FSM:  W_IDLE → W_DATA → W_RESP
//  AXI4-Lite Read  FSM:  R_IDLE → R_DATA
// ============================================================================

module gpio_peripheral (
    input  logic        clk,
    input  logic        reset,

    // AXI4-Lite Slave interface
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // GPIO pins
    output logic [31:0] gpio_out,
    input  logic [31:0] gpio_in
);

    // ---------------------------------------------------------------
    //  Registers
    // ---------------------------------------------------------------
    logic [31:0] dir_reg;     // 0x00: direction (0=input, 1=output)
    logic [31:0] out_reg;     // 0x04: output data
    // gpio_in is sampled directly — no register needed

    // ---------------------------------------------------------------
    //  AXI4-Lite Write Channel FSM
    // ---------------------------------------------------------------
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wstate_t;
    wstate_t wstate;
    logic [31:0] awaddr_latched;

    always_ff @(posedge clk) begin
        if (reset) begin
            wstate   <= W_IDLE;
            dir_reg  <= 32'b0;
            out_reg  <= 32'b0;
        end else begin
            case (wstate)
                W_IDLE: begin
                    if (awvalid) begin
                        awaddr_latched <= awaddr;
                        wstate         <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (wvalid) begin
                        case (awaddr_latched[7:0])
                            8'h00: dir_reg <= wdata;   // GPIO direction
                            8'h04: out_reg <= wdata;   // GPIO output data
                            // 0x08 is read-only (input data) — ignore writes
                            default: ;
                        endcase
                        wstate <= W_RESP;
                    end
                end
                W_RESP: begin
                    if (bready)
                        wstate <= W_IDLE;
                end
                default: wstate <= W_IDLE;
            endcase
        end
    end

    assign awready = (wstate == W_IDLE);
    assign wready  = (wstate == W_DATA);
    assign bvalid  = (wstate == W_RESP);
    assign bresp   = 2'b00;   // OKAY

    // ---------------------------------------------------------------
    //  AXI4-Lite Read Channel FSM
    // ---------------------------------------------------------------
    typedef enum logic [1:0] {R_IDLE, R_DATA} rstate_t;
    rstate_t rstate;
    logic [31:0] araddr_latched;

    always_ff @(posedge clk) begin
        if (reset) begin
            rstate <= R_IDLE;
        end else begin
            case (rstate)
                R_IDLE: begin
                    if (arvalid) begin
                        araddr_latched <= araddr;
                        rstate         <= R_DATA;
                    end
                end
                R_DATA: begin
                    if (rready)
                        rstate <= R_IDLE;
                end
                default: rstate <= R_IDLE;
            endcase
        end
    end

    assign arready = (rstate == R_IDLE);
    assign rvalid  = (rstate == R_DATA);
    assign rresp   = 2'b00;

    // ---------------------------------------------------------------
    //  Read Data Mux
    // ---------------------------------------------------------------
    always_comb begin
        case (araddr_latched[7:0])
            8'h00:   rdata = dir_reg;
            8'h04:   rdata = out_reg;
            8'h08:   rdata = gpio_in;    // read-only: sampled input pins
            default: rdata = 32'b0;
        endcase
    end

    // ---------------------------------------------------------------
    //  Output Pin Logic
    //  Pins where dir_reg bit = 1 drive from out_reg,
    //  Pins where dir_reg bit = 0 are tri-stated (driven to 0 here
    //  since FPGA fabric doesn't have true tri-state internally).
    // ---------------------------------------------------------------
    assign gpio_out = out_reg & dir_reg;

endmodule
