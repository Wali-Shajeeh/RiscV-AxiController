module data_mem (
    input  logic        clk,
    input  logic [31:0] addr,          // ALU se aaya address (base + offset)
    input  logic [31:0] write_data,    // store ke liye data (register se)
    input  logic        mem_read,      // load enable
    input  logic         mem_write,    // store enable

    output logic [31:0] read_data      // load ke liye data (register file ko jayega)
);

    // 1024 words x 32-bit (4KB data memory)
    logic [31:0] mem [0:1023];

    // Synchronous write
    always_ff @(posedge clk) begin
        if (mem_write)
            mem[addr[11:2]] <= write_data;
    end

    // Combinational read (single-cycle core requirement)
    assign read_data = (mem_read) ? mem[addr[11:2]] : 32'b0;

endmodule
