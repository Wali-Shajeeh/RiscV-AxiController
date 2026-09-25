// ============================================================
//  uart_regs.sv — UART Memory-Mapped AXI4-Lite Register Block
//
//  Memory Map (relative to UART base address 0x4003_0000):
//
//    Offset 0x00 / 0x80 : UART_TX_DATA   (W)  – write byte here to transmit
//                                        (R)  – reads last byte written
//    Offset 0x04 / 0x84 : UART_TX_STATUS (R)  – bit[0] = tx_ready (1 = idle, OK to send)
//    Offset 0x08 / 0x88 : UART_RX_DATA   (R)  – last received byte
//                                               (reading automatically clears rx_ready)
//    Offset 0x0C / 0x8C : UART_RX_STATUS (R)  – bit[0] = rx_ready (1 = new byte waiting)
//
//  Parameters:
//    CLK_FREQ  — System clock frequency in Hz (default 50 MHz)
//    BAUD_RATE — Desired baud rate for TX/RX  (default 9600)
// ============================================================

`timescale 1ns / 1ps

module uart_regs #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 9600
)(
    input  logic        clk,
    input  logic        reset,

    // AXI4-Lite Slave Interface
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // UART Serial Pins
    output logic        tx,
    input  logic        rx,

    // Status / Parallel Data Outputs
    output logic        rx_ready,
    output logic [7:0]  rx_data
);

    // ── Internal UART Signals ──────────────────────────────────
    logic       tx_busy;
    logic       tx_start;
    logic [7:0] tx_byte;

    logic [7:0] rx_data_wire;
    logic       rx_ready_wire;
    logic [7:0] rx_buf;
    logic       rx_ready_flag;

    // ── Instantiate TX ─────────────────────────────────────────
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk      (clk),
        .reset    (reset),
        .tx_start (tx_start),
        .tx_data  (tx_byte),
        .tx       (tx),
        .tx_busy  (tx_busy)
    );

    // ── Instantiate RX ─────────────────────────────────────────
    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk      (clk),
        .reset    (reset),
        .rx       (rx),
        .rx_data  (rx_data_wire),
        .rx_ready (rx_ready_wire)
    );

    assign rx_ready = rx_ready_flag;
    assign rx_data  = rx_buf;

    // ── AXI4-Lite Write Channel FSM ────────────────────────────
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wstate_t;
    wstate_t wstate;
    logic [31:0] awaddr_latched;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            wstate         <= W_IDLE;
            tx_start       <= 1'b0;
            tx_byte        <= 8'h00;
            awaddr_latched <= 32'h0;
        end else begin
            tx_start <= 1'b0;  // Default: single-cycle strobe

            case (wstate)
                W_IDLE: begin
                    if (awvalid) begin
                        awaddr_latched <= awaddr;
                        wstate         <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (wvalid) begin
                        // Match offset 0x00 or 0x80 for TX_DATA
                        if (awaddr_latched[7:0] == 8'h00 || awaddr_latched[7:0] == 8'h80) begin
                            tx_byte  <= wdata[7:0];
                            tx_start <= 1'b1;  // trigger UART transmission
                        end
                        wstate <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (bready) begin
                        wstate <= W_IDLE;
                    end
                end

                default: wstate <= W_IDLE;
            endcase
        end
    end

    assign awready = (wstate == W_IDLE);
    assign wready  = (wstate == W_DATA);
    assign bvalid  = (wstate == W_RESP);
    assign bresp   = 2'b00;  // OKAY

    // ── AXI4-Lite Read Channel FSM ─────────────────────────────
    typedef enum logic [1:0] {R_IDLE, R_DATA} rstate_t;
    rstate_t rstate;
    logic [31:0] araddr_latched;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rstate         <= R_IDLE;
            araddr_latched <= 32'h0;
        end else begin
            case (rstate)
                R_IDLE: begin
                    if (arvalid) begin
                        araddr_latched <= araddr;
                        rstate         <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (rready) begin
                        rstate <= R_IDLE;
                    end
                end

                default: rstate <= R_IDLE;
            endcase
        end
    end

    assign arready = (rstate == R_IDLE);
    assign rvalid  = (rstate == R_DATA);
    assign rresp   = 2'b00;  // OKAY

    // ── Read Multiplexer ───────────────────────────────────────
    always_comb begin
        case (araddr_latched[7:0])
            8'h00, 8'h80: rdata = {24'h0, tx_byte};            // TX_DATA: last written byte
            8'h04, 8'h84: rdata = {31'h0, ~tx_busy};           // TX_STATUS: bit[0] = tx_ready (1 = idle/ready)
            8'h08, 8'h88: rdata = {24'h0, rx_buf};             // RX_DATA: received byte
            8'h0C, 8'h8C: rdata = {31'h0, rx_ready_flag};      // RX_STATUS: bit[0] = 1 if byte waiting
            default:      rdata = 32'h00000000;
        endcase
    end

    // ── Latch Received Byte & Clear Flag on Read ───────────────
    logic rx_read_completed;
    assign rx_read_completed = (rstate == R_DATA) && rready &&
                               (araddr_latched[7:0] == 8'h08 || araddr_latched[7:0] == 8'h88);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_buf        <= 8'h00;
            rx_ready_flag <= 1'b0;
        end else begin
            if (rx_ready_wire) begin
                rx_buf        <= rx_data_wire;
                rx_ready_flag <= 1'b1;
            end else if (rx_read_completed) begin
                rx_ready_flag <= 1'b0;  // Autoclear on reading RX_DATA
            end
        end
    end

endmodule
