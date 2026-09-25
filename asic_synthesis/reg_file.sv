module reg_file (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  rs1,         
    input  logic [4:0]  rs2,          
    input  logic [4:0]  rd,           
    input  logic [31:0] write_data,   
    input  logic        reg_write,    

    output logic [31:0] read_data1,   
    output logic [31:0] read_data2    
);

    logic [31:0] registers [0:31];  

    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    always_ff @(posedge clk) begin
        if (reset) begin
            integer i;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end
        else if (reg_write && (rd != 5'b0)) begin
            registers[rd] <= write_data;
        end
    end

endmodule
