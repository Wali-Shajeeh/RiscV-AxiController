module instr_mem (
    input  logic        clk,
    input  logic [31:0] addr,          
    output logic [31:0] instruction
);

`ifndef SYNTHESIS
    logic [31:0] mem [0:1023];

    initial begin
        $readmemh("hex_file.hex", mem);
    end

    assign instruction = mem[addr[11:2]];

`else
    instr_rom2 u_instr_rom (
        .address ( addr[11:2] ),   
        .clock   ( clk         ),
        .q       ( instruction )
    );

`endif

endmodule
