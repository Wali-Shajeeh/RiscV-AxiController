module instr_mem (
    input  logic        clk,
    input  logic [31:0] addr,          
    output logic [31:0] instruction
);

    logic [31:0] mem [0:1023];

    // For simulation, load program. Synthesis tools (like Genus) can synthesize ROM contents or treat as memory array.
    initial begin
        $readmemh("hex_file.hex", mem);
    end

    assign instruction = mem[addr[11:2]];

endmodule