// =============================================================
// pc_reg.sv — Program Counter Register (Multicycle version)
// CHANGED: Added pc_write enable — PC only updates when FSM says so
// =============================================================

module pc_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        pc_write,       // NEW: write enable from FSM
    input  logic [31:0] pc_next,
    output logic [31:0] pc_out
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 32'h0000_0000;
        else if (pc_write)              // CHANGED: only update when enabled
            pc_out <= pc_next;
    end

endmodule
