// ============================================================
//  uart_tx.sv — UART Transmitter (8N1)
//
//  Parameters:
//    CLK_FREQ  — System clock frequency in Hz (default 50 MHz)
//    BAUD_RATE — Desired baud rate             (default 9600)
//
//  Interface:
//    clk       — System clock
//    reset     — Active-high synchronous/asynchronous reset
//    tx_start  — Assert for at least one clk cycle to begin TX
//    tx_data   — Byte to send (latched on tx_start while IDLE)
//    tx        — Serial output line (idle-high)
//    tx_busy   — High while a frame is being transmitted
// ============================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // FSM States
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } tx_state_t;

    tx_state_t  state;
    logic [31:0] clk_count;
    logic [2:0]  bit_idx;
    logic [7:0]  shift_reg;

    assign tx_busy = (state != IDLE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            tx        <= 1'b1;  // Idle-high line
            clk_count <= 32'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            case (state)

                // ── IDLE: wait for tx_start pulse ─────────────────────
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        clk_count <= 32'd0;
                        state     <= START;
                    end
                end

                // ── START BIT (logic 0) ───────────────────────────────
                START: begin
                    tx <= 1'b0;
                    if (clk_count >= CLKS_PER_BIT - 1) begin
                        clk_count <= 32'd0;
                        bit_idx   <= 3'd0;
                        state     <= DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                // ── DATA BITS (8 bits, LSB first) ─────────────────────
                DATA: begin
                    tx <= shift_reg[0];
                    if (clk_count >= CLKS_PER_BIT - 1) begin
                        clk_count <= 32'd0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                // ── STOP BIT (logic 1) ────────────────────────────────
                STOP: begin
                    tx <= 1'b1;
                    if (clk_count >= CLKS_PER_BIT - 1) begin
                        clk_count <= 32'd0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
