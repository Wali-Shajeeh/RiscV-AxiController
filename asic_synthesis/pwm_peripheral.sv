module pwm_peripheral (
    input  logic clk,
    input  logic reset,

    // AXI4-Lite Slave interface
    input  logic [31:0] awaddr,
    input  logic         awvalid,
    output logic         awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic         wvalid,
    output logic         wready,
    output logic [1:0]  bresp,
    output logic         bvalid,
    input  logic         bready,
    input  logic [31:0] araddr,
    input  logic         arvalid,
    output logic         arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic         rvalid,
    input  logic         rready,

    output logic         pwm_out          
);
    logic [31:0] control_reg;    
    logic [31:0] period_reg;     
    logic [31:0] duty_reg;       
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wstate_t;
    wstate_t wstate;
    logic [31:0] awaddr_latched;

    always_ff @(posedge clk) begin
        if (reset) begin
            wstate       <= W_IDLE;
            control_reg  <= 32'b0;
            period_reg   <= 32'b0;
            duty_reg     <= 32'b0;
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
                            8'h00: control_reg <= wdata;
                            8'h04: period_reg  <= wdata;
                            8'h08: duty_reg    <= wdata;
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

    always_comb begin
        case (araddr_latched[7:0])
            8'h00:   rdata = control_reg;
            8'h04:   rdata = period_reg;
            8'h08:   rdata = duty_reg;
            default: rdata = 32'b0;
        endcase
    end

    logic [31:0] counter;

    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= 32'b0;
        end else if (control_reg[0]) begin   // enable bit
            if (counter >= period_reg)
                counter <= 32'b0;
            else
                counter <= counter + 1;
        end
    end

    assign pwm_out = (control_reg[0]) && (counter < duty_reg);

endmodule
