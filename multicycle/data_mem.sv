module data_mem (
    input  logic        clk,
    input  logic [31:0] addr,          // ALU se aaya address (base + offset)
    input  logic [31:0] write_data,    // store ke liye data (register se)
    input  logic        mem_read,      // load enable
    input  logic        mem_write,     // store enable
    input  logic [2:0]  funct3,        // FIX: size select for byte/half/word

    output logic [31:0] read_data      // load ke liye data (register file ko jayega)
);

    logic [9:0]  word_addr;
    logic [1:0]  byte_offset;

    assign word_addr   = addr[11:2];
    assign byte_offset = addr[1:0];

`ifndef SYNTHESIS
    // -----------------------------------------------------------
    // SIMULATION PATH — behavioral word-addressed array
    // -----------------------------------------------------------
    logic [31:0] mem [0:1023];   // 1024 words = 4KB data memory

    logic [31:0] word_data;      // raw word read from memory
    assign word_data = mem[word_addr];

    // -----------------------------------------------------------
    // Synchronous write with byte/halfword/word support
    // -----------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                // ---- SB: store byte ----
                3'b000: begin
                    case (byte_offset)
                        2'b00: mem[word_addr][7:0]   <= write_data[7:0];
                        2'b01: mem[word_addr][15:8]  <= write_data[7:0];
                        2'b10: mem[word_addr][23:16] <= write_data[7:0];
                        2'b11: mem[word_addr][31:24] <= write_data[7:0];
                    endcase
                end

                // ---- SH: store halfword ----
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: mem[word_addr][15:0]  <= write_data[15:0];
                        1'b1: mem[word_addr][31:16] <= write_data[15:0];
                    endcase
                end

                // ---- SW: store word ----
                3'b010: begin
                    mem[word_addr] <= write_data;
                end

                default: mem[word_addr] <= write_data;
            endcase
        end
    end

    // -----------------------------------------------------------
    // Combinational read with sign/zero-extension
    // -----------------------------------------------------------
    always_comb begin
        read_data = 32'b0;
        if (mem_read) begin
            case (funct3)
                // ---- LB: load byte, sign-extend ----
                3'b000: begin
                    case (byte_offset)
                        2'b00: read_data = {{24{word_data[7]}},  word_data[7:0]};
                        2'b01: read_data = {{24{word_data[15]}}, word_data[15:8]};
                        2'b10: read_data = {{24{word_data[23]}}, word_data[23:16]};
                        2'b11: read_data = {{24{word_data[31]}}, word_data[31:24]};
                    endcase
                end

                // ---- LH: load halfword, sign-extend ----
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: read_data = {{16{word_data[15]}}, word_data[15:0]};
                        1'b1: read_data = {{16{word_data[31]}}, word_data[31:16]};
                    endcase
                end

                // ---- LW: load word ----
                3'b010: read_data = word_data;

                // ---- LBU: load byte, zero-extend ----
                3'b100: begin
                    case (byte_offset)
                        2'b00: read_data = {24'b0, word_data[7:0]};
                        2'b01: read_data = {24'b0, word_data[15:8]};
                        2'b10: read_data = {24'b0, word_data[23:16]};
                        2'b11: read_data = {24'b0, word_data[31:24]};
                    endcase
                end

                // ---- LHU: load halfword, zero-extend ----
                3'b101: begin
                    case (byte_offset[1])
                        1'b0: read_data = {16'b0, word_data[15:0]};
                        1'b1: read_data = {16'b0, word_data[31:16]};
                    endcase
                end

                default: read_data = word_data;
            endcase
        end
    end

`else
    // -----------------------------------------------------------
    // SYNTHESIS PATH — Quartus altsyncram-based RAM
    // NOTE: For full byte/halfword support in synthesis, generate
    //       a RAM IP with 4-byte byte-enable, or add a wrapper
    //       that does read-modify-write for sub-word stores.
    // -----------------------------------------------------------
    logic [31:0] ram_q;

    data_ram u_data_ram (
        .address ( word_addr   ),
        .clock   ( clk         ),
        .data    ( write_data  ),
        .wren    ( mem_write   ),
        .q       ( ram_q       )
    );

    // Read-side sign/zero extension for synthesis path
    always_comb begin
        read_data = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b000: begin // LB
                    case (byte_offset)
                        2'b00: read_data = {{24{ram_q[7]}},  ram_q[7:0]};
                        2'b01: read_data = {{24{ram_q[15]}}, ram_q[15:8]};
                        2'b10: read_data = {{24{ram_q[23]}}, ram_q[23:16]};
                        2'b11: read_data = {{24{ram_q[31]}}, ram_q[31:24]};
                    endcase
                end
                3'b001: begin // LH
                    case (byte_offset[1])
                        1'b0: read_data = {{16{ram_q[15]}}, ram_q[15:0]};
                        1'b1: read_data = {{16{ram_q[31]}}, ram_q[31:16]};
                    endcase
                end
                3'b010: read_data = ram_q; // LW
                3'b100: begin // LBU
                    case (byte_offset)
                        2'b00: read_data = {24'b0, ram_q[7:0]};
                        2'b01: read_data = {24'b0, ram_q[15:8]};
                        2'b10: read_data = {24'b0, ram_q[23:16]};
                        2'b11: read_data = {24'b0, ram_q[31:24]};
                    endcase
                end
                3'b101: begin // LHU
                    case (byte_offset[1])
                        1'b0: read_data = {16'b0, ram_q[15:0]};
                        1'b1: read_data = {16'b0, ram_q[31:16]};
                    endcase
                end
                default: read_data = ram_q;
            endcase
        end
    end

`endif

endmodule
