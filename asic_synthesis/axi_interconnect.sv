module axi_interconnect (
    input  logic clk,
    input  logic reset,

    input  logic [31:0]  slave_awaddr,
    input  logic         slave_awvalid,
    output logic         slave_awready,

    
    input  logic [31:0]  slave_wdata,
    input  logic [3:0]   slave_wstrb,
    input  logic         slave_wvalid,
    output logic         slave_wready,

    
    output logic [1:0]   slave_bresp,
    output logic         slave_bvalid,
    input  logic         slave_bready,

    
    input  logic [31:0]  slave_araddr,
    input  logic         slave_arvalid,
    output logic         slave_arready,

    
    output logic [31:0]  slave_rdata,
    output logic [1:0]   slave_rresp,
    output logic         slave_rvalid,
    input  logic         slave_rready,


    output logic [31:0] pwm_awaddr,
    output logic         pwm_awvalid,
    input  logic         pwm_awready,
    output logic [31:0] pwm_wdata,
    output logic [3:0]  pwm_wstrb,
    output logic         pwm_wvalid,
    input  logic         pwm_wready,
    input  logic [1:0]  pwm_bresp,
    input  logic         pwm_bvalid,
    output logic         pwm_bready,
    output logic [31:0] pwm_araddr,
    output logic         pwm_arvalid,
    input  logic         pwm_arready,
    input  logic [31:0] pwm_rdata,
    input  logic [1:0]  pwm_rresp,
    input  logic         pwm_rvalid,
    output logic         pwm_rready,

    output logic [31:0] timer_awaddr,
    output logic         timer_awvalid,
    input  logic         timer_awready,
    output logic [31:0] timer_wdata,
    output logic [3:0]  timer_wstrb,
    output logic         timer_wvalid,
    input  logic         timer_wready,
    input  logic [1:0]  timer_bresp,
    input  logic         timer_bvalid,
    output logic         timer_bready,
    output logic [31:0] timer_araddr,
    output logic         timer_arvalid,
    input  logic         timer_arready,
    input  logic [31:0] timer_rdata,
    input  logic [1:0]  timer_rresp,
    input  logic         timer_rvalid,
    output logic         timer_rready,

    output logic [31:0] gpio_awaddr,
    output logic         gpio_awvalid,
    input  logic         gpio_awready,
    output logic [31:0] gpio_wdata,
    output logic [3:0]  gpio_wstrb,
    output logic         gpio_wvalid,
    input  logic         gpio_wready,
    input  logic [1:0]  gpio_bresp,
    input  logic         gpio_bvalid,
    output logic         gpio_bready,
    output logic [31:0] gpio_araddr,
    output logic         gpio_arvalid,
    input  logic         gpio_arready,
    input  logic [31:0] gpio_rdata,
    input  logic [1:0]  gpio_rresp,
    input  logic         gpio_rvalid,
    output logic         gpio_rready,

	 
    output logic [31:0] uart_awaddr,
    output logic         uart_awvalid,
    input  logic         uart_awready,
    output logic [31:0] uart_wdata,
    output logic [3:0]  uart_wstrb,
    output logic         uart_wvalid,
    input  logic         uart_wready,
    input  logic [1:0]  uart_bresp,
    input  logic         uart_bvalid,
    output logic         uart_bready,
    output logic [31:0] uart_araddr,
    output logic         uart_arvalid,
    input  logic         uart_arready,
    input  logic [31:0] uart_rdata,
    input  logic [1:0]  uart_rresp,
    input  logic         uart_rvalid,
    output logic         uart_rready
);

    typedef enum logic [2:0] {
        SEL_NONE, SEL_PWM, SEL_TIMER, SEL_GPIO, SEL_UART
    } slave_sel_t;

    slave_sel_t wr_sel_comb, rd_sel_comb;
    slave_sel_t wr_sel, rd_sel;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_sel <= SEL_NONE;
            rd_sel <= SEL_NONE;
        end else begin
            if (slave_awvalid && slave_awready) wr_sel <= wr_sel_comb;
            if (slave_arvalid && slave_arready) rd_sel <= rd_sel_comb;
        end
    end
    always_comb begin
        if (slave_awaddr[31:16] == 16'h4000)      wr_sel_comb = SEL_PWM;
        else if (slave_awaddr[31:16] == 16'h4001) wr_sel_comb = SEL_TIMER;
        else if (slave_awaddr[31:16] == 16'h4002) wr_sel_comb = SEL_GPIO;
        else if (slave_awaddr[31:16] == 16'h4003) wr_sel_comb = SEL_UART;
        else                                       wr_sel_comb = SEL_NONE;
    end
    always_comb begin
        if (slave_araddr[31:16] == 16'h4000)      rd_sel_comb = SEL_PWM;
        else if (slave_araddr[31:16] == 16'h4001) rd_sel_comb = SEL_TIMER;
        else if (slave_araddr[31:16] == 16'h4002) rd_sel_comb = SEL_GPIO;
        else if (slave_araddr[31:16] == 16'h4003) rd_sel_comb = SEL_UART;
        else                                       rd_sel_comb = SEL_NONE;
    end

    assign pwm_awaddr    = slave_awaddr;
    assign timer_awaddr  = slave_awaddr;
    assign gpio_awaddr   = slave_awaddr;
    assign uart_awaddr   = slave_awaddr;

    assign pwm_awvalid   = slave_awvalid & (wr_sel_comb == SEL_PWM);
    assign timer_awvalid = slave_awvalid & (wr_sel_comb == SEL_TIMER);
    assign gpio_awvalid  = slave_awvalid & (wr_sel_comb == SEL_GPIO);
    assign uart_awvalid  = slave_awvalid & (wr_sel_comb == SEL_UART);

    always_comb begin
        case (wr_sel_comb)
            SEL_PWM:   slave_awready = pwm_awready;
            SEL_TIMER: slave_awready = timer_awready;
            SEL_GPIO:  slave_awready = gpio_awready;
            SEL_UART:  slave_awready = uart_awready;
            default:   slave_awready = 1'b0;
        endcase
    end

    // -----------------------------------------------------------
    // Write Data Channel
    // -----------------------------------------------------------
    assign pwm_wdata    = slave_wdata;
    assign timer_wdata  = slave_wdata;
    assign gpio_wdata   = slave_wdata;
    assign uart_wdata   = slave_wdata;

    assign pwm_wstrb    = slave_wstrb;
    assign timer_wstrb  = slave_wstrb;
    assign gpio_wstrb   = slave_wstrb;
    assign uart_wstrb   = slave_wstrb;

    assign pwm_wvalid   = slave_wvalid & (wr_sel == SEL_PWM);
    assign timer_wvalid = slave_wvalid & (wr_sel == SEL_TIMER);
    assign gpio_wvalid  = slave_wvalid & (wr_sel == SEL_GPIO);
    assign uart_wvalid  = slave_wvalid & (wr_sel == SEL_UART);

    always_comb begin
        case (wr_sel)
            SEL_PWM:   slave_wready = pwm_wready;
            SEL_TIMER: slave_wready = timer_wready;
            SEL_GPIO:  slave_wready = gpio_wready;
            SEL_UART:  slave_wready = uart_wready;
            default:   slave_wready = 1'b0;
        endcase
    end

    // -----------------------------------------------------------
    // Write Response Channel — selected slave se wapis route
    // -----------------------------------------------------------
    assign pwm_bready   = slave_bready & (wr_sel == SEL_PWM);
    assign timer_bready = slave_bready & (wr_sel == SEL_TIMER);
    assign gpio_bready  = slave_bready & (wr_sel == SEL_GPIO);
    assign uart_bready  = slave_bready & (wr_sel == SEL_UART);

    always_comb begin
        case (wr_sel)
            SEL_PWM: begin
                slave_bvalid = pwm_bvalid;
                slave_bresp  = pwm_bresp;
            end
            SEL_TIMER: begin
                slave_bvalid = timer_bvalid;
                slave_bresp  = timer_bresp;
            end
            SEL_GPIO: begin
                slave_bvalid = gpio_bvalid;
                slave_bresp  = gpio_bresp;
            end
            SEL_UART: begin
                slave_bvalid = uart_bvalid;
                slave_bresp  = uart_bresp;
            end
            default: begin
                slave_bvalid = 1'b0;
                slave_bresp  = 2'b11;   // DECERR — invalid address
            end
        endcase
    end

    // -----------------------------------------------------------
    // Read Address Channel
    // -----------------------------------------------------------
    assign pwm_araddr    = slave_araddr;
    assign timer_araddr  = slave_araddr;
    assign gpio_araddr   = slave_araddr;
    assign uart_araddr   = slave_araddr;

    assign pwm_arvalid   = slave_arvalid & (rd_sel_comb == SEL_PWM);
    assign timer_arvalid = slave_arvalid & (rd_sel_comb == SEL_TIMER);
    assign gpio_arvalid  = slave_arvalid & (rd_sel_comb == SEL_GPIO);
    assign uart_arvalid  = slave_arvalid & (rd_sel_comb == SEL_UART);

    always_comb begin
        case (rd_sel_comb)
            SEL_PWM:   slave_arready = pwm_arready;
            SEL_TIMER: slave_arready = timer_arready;
            SEL_GPIO:  slave_arready = gpio_arready;
            SEL_UART:  slave_arready = uart_arready;
            default:   slave_arready = 1'b0;
        endcase
    end

    // -----------------------------------------------------------
    // Read Data Channel — selected slave se wapis route
    // -----------------------------------------------------------
    assign pwm_rready   = slave_rready & (rd_sel == SEL_PWM);
    assign timer_rready = slave_rready & (rd_sel == SEL_TIMER);
    assign gpio_rready  = slave_rready & (rd_sel == SEL_GPIO);
    assign uart_rready  = slave_rready & (rd_sel == SEL_UART);

    always_comb begin
        case (rd_sel)
            SEL_PWM: begin
                slave_rvalid = pwm_rvalid;
                slave_rdata  = pwm_rdata;
                slave_rresp  = pwm_rresp;
            end
            SEL_TIMER: begin
                slave_rvalid = timer_rvalid;
                slave_rdata  = timer_rdata;
                slave_rresp  = timer_rresp;
            end
            SEL_GPIO: begin
                slave_rvalid = gpio_rvalid;
                slave_rdata  = gpio_rdata;
                slave_rresp  = gpio_rresp;
            end
            SEL_UART: begin
                slave_rvalid = uart_rvalid;
                slave_rdata  = uart_rdata;
                slave_rresp  = uart_rresp;
            end
            default: begin
                slave_rvalid = 1'b0;
                slave_rdata  = 32'b0;
                slave_rresp  = 2'b11;   // DECERR
            end
        endcase
    end

endmodule


