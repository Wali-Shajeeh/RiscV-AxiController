module data_mem (
    input  logic        clk,
    input  logic [31:0] addr,          // ALU se aaya address (base + offset)
    input  logic [31:0] write_data,    // store ke liye data (register se)
    input  logic        mem_read,      // load enable
    input  logic         mem_write,    // store enable

    output logic [31:0] read_data      // load ke liye data (register file ko jayega)
);

`ifndef SYNTHESIS
    // -----------------------------------------------------------
    // SIMULATION PATH — behavioral array
    // -----------------------------------------------------------
    logic [31:0] mem [0:1023];   // 1024 words = 4KB data memory

    /*initial begin
        // data memory generally program se pehle empty/zero hoti hai
        integer i;
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'b0;
    end*/

    // Synchronous write
    always_ff @(posedge clk) begin
        if (mem_write)
            mem[addr[11:2]] <= write_data;
    end

    // Combinational read (single-cycle core ke liye same-cycle data chahiye)
    assign read_data = (mem_read) ? mem[addr[11:2]] : 32'b0;

`else
    // -----------------------------------------------------------
    // SYNTHESIS PATH — Quartus altsyncram-based RAM (unregistered read)
    // -----------------------------------------------------------
    // NOTE: 'data_ram' Quartus IP Catalog se generate karni hogi
    //       (On-Chip Memory -> RAM: 1-PORT), 1024 words x 32-bit,
    //       Output = UNREGISTERED (0 latency, jaisa instr_rom2 mein kiya)
    data_ram u_data_ram (
        .address ( addr[11:2]   ),
        .clock   ( clk          ),
        .data    ( write_data   ),
        .wren    ( mem_write    ),
        .q       ( read_data    )
    );

`endif

endmodule
