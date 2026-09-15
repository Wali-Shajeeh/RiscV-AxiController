module axi_adapter (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] addr,          
    input  logic [31:0] write_data,   
    input  logic        read_req,       
    input  logic        write_req,      
    output logic [31:0] read_data,      
    output logic        mem_ready,  // 1 when transaction complete, 0 when busy        

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

    // Write Address Channel
    assign awaddr  = addr;
    assign awvalid = (state == WRITE_ADDR);

    // Write Data Channel
    assign wdata   = write_data;
    assign wstrb   = 4'b1111;              // full word write (byte enables all high)
    assign wvalid  = (state == WRITE_DATA);

    // Write Response Channel
    assign bready  = (state == WRITE_RESP);

    // Read Address Channel
    assign araddr  = addr;
    assign arvalid = (state == READ_ADDR);

    // Read Data Channel
    assign rready  = (state == READ_DATA);

    // -----------------------------------------------------------
    // Captured read data (registered when rvalid asserted)
    // -----------------------------------------------------------
    logic [31:0] read_data_reg;

    always_ff @(posedge clk) begin
        if (state == READ_DATA && rvalid)
            read_data_reg <= rdata;
    end

    assign read_data = (state == READ_DATA && rvalid) ? rdata : read_data_reg;

    always_comb begin
        if (read_req || write_req) begin
            if ((state == READ_DATA && rvalid) || (state == WRITE_RESP && bvalid))
                mem_ready = 1'b1;
            else
                mem_ready = 1'b0;
        end else begin
            mem_ready = 1'b1; // Idle or not requesting
        end
    end

endmodule
