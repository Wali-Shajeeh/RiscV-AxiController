module axi_adapter (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] addr,          
    input  logic [31:0] write_data,   
    input  logic        read_req,       
    input  logic        write_req,      
    output logic [31:0] read_data,      
    output logic        busy,   // must be 1 to keep core stall        

    // Write Address Channel
    output logic [31:0] awaddr,
    output logic        awvalid,
    input  logic        awready,

    // Write Data Channel
    output logic [31:0] wdata,
    output logic [3:0]  wstrb,
    output logic        wvalid,
    input  logic        wready,

    // Write Response Channel
    input  logic [1:0]  bresp,
    input  logic        bvalid,
    output logic        bready,

    // Read Address Channel
    output logic [31:0] araddr,
    output logic        arvalid,
    input  logic        arready,

    // Read Data Channel
    input  logic [31:0] rdata,
    input  logic [1:0]  rresp,
    input  logic        rvalid,
    output logic        rready
);
    typedef enum logic [2:0] {
        IDLE,
        WRITE_ADDR,
        WRITE_DATA,
        WRITE_RESP,
        READ_ADDR,
        READ_DATA
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (write_req)
                    next_state = WRITE_ADDR;
                else if (read_req)
                    next_state = READ_ADDR;
            end

            WRITE_ADDR: begin
                if (awready)
                    next_state = WRITE_DATA;
            end

            WRITE_DATA: begin
                if (wready)
                    next_state = WRITE_RESP;
            end

            WRITE_RESP: begin
                if (bvalid)
                    next_state = IDLE;
            end

            READ_ADDR: begin
                if (arready)
                    next_state = READ_DATA;
            end

            READ_DATA: begin
                if (rvalid)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    logic [31:0] latched_addr;
    logic [31:0] latched_wdata;

    always_ff @(posedge clk) begin
        if (reset) begin
            latched_addr  <= 32'b0;
            latched_wdata <= 32'b0;
        end else if (state == IDLE && (write_req || read_req)) begin
            latched_addr  <= addr;
            latched_wdata <= write_data;
        end
    end

    // Write Address Channel
    assign awaddr  = (state == IDLE) ? addr : latched_addr;
    assign awvalid = (state == WRITE_ADDR);

    // Write Data Channel
    assign wdata   = (state == IDLE) ? write_data : latched_wdata;
    assign wstrb   = 4'b1111;              // full word write (byte enables all high)
    assign wvalid  = (state == WRITE_DATA);

    // Write Response Channel
    assign bready  = (state == WRITE_RESP);

    // Read Address Channel
    assign araddr  = (state == IDLE) ? addr : latched_addr;
    assign arvalid = (state == READ_ADDR);

    // Read Data Channel
    assign rready  = (state == READ_DATA);

    // -----------------------------------------------------------
    // Captured read data (registered when rvalid asserted)
    // -----------------------------------------------------------
    logic [31:0] read_data_reg;

    always_ff @(posedge clk) begin
        if (reset)
            read_data_reg <= 32'b0;
        else if (state == READ_DATA && rvalid)
            read_data_reg <= rdata;
    end

    assign read_data = (state == READ_DATA && rvalid) ? rdata : read_data_reg;

    logic done;
    assign done = (state == WRITE_RESP && bvalid) || (state == READ_DATA && rvalid);

    assign busy = ((state != IDLE) || write_req || read_req) && !done;

endmodule
