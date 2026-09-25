// ============================================================
//  uart_rx.sv — UART Receiver (8N1, mid-bit sampling)
//
//  Parameters:
//    CLK_FREQ  — System clock frequency in Hz (default 50 MHz)
//    BAUD_RATE — Desired baud rate             (default 9600)
//
//  Interface:
//    clk       — System clock
//    reset     — Active-high reset
//    rx        — Serial input line (idle-high)
//    rx_data   — Received byte (valid when rx_ready pulses high)
//    rx_ready  — 1-cycle pulse when a valid byte has been captured
// ============================================================

`timescale 1ns / 1ps

module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 9600
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_ready
);

    localparam int CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam int CLKS_PER_HALF = CLKS_PER_BIT / 2;

    // FSM States
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } rx_state_t;

    rx_state_t   state;
    logic [31:0] clk_count;
    logic [2:0]  bit_idx;
    logic [7:0]  shift_reg;

    // 2-FF synchronizer on rx line (reset to 1'b1 to prevent spurious start bits)
    logic rx_s1, rx_sync;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_s1   <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_s1   <= rx;
            rx_sync <= rx_s1;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            clk_count <= 32'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_ready  <= 1'b0;
        end else begin
            rx_ready <= 1'b0;  // Default: pulse clears each cycle

            case (state)

                // ── IDLE: wait for falling edge (start bit) ───────────
                IDLE: begin
                    clk_count <= 32'd0;
                    bit_idx   <= 3'd0;
                    if (rx_sync == 1'b0) begin
                        state <= START;
                    end
                end

                // ── START: sample mid-bit to verify valid start ───────
                START: begin
                    if (clk_count >= CLKS_PER_HALF - 1) begin
                        if (rx_sync == 1'b0) begin  // Valid start bit confirmed
                            clk_count <= 32'd0;
                            state     <= DATA;
                        end else begin              // False glitch -> abort to IDLE
                            state     <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                // ── DATA: sample each bit at center of bit period ─────
                DATA: begin
                    if (clk_count >= CLKS_PER_BIT - 1) begin
                        clk_count <= 32'd0;
                        shift_reg <= {rx_sync, shift_reg[7:1]};  // LSB first
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                // ── STOP: verify stop bit (high) and latch data ───────
                STOP: begin
                    if (clk_count >= CLKS_PER_BIT - 1) begin
                        if (rx_sync == 1'b1) begin  // Valid stop bit
                            rx_data  <= shift_reg;
                            rx_ready <= 1'b1;       // Single cycle strobe
                        end
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
