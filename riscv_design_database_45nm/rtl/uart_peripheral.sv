// ============================================================
//  uart_peripheral.sv — Top-level wrapper for UART AXI4-Lite
//  Provides consistent naming with pwm_peripheral and timer_peripheral.
// ============================================================

`timescale 1ns / 1ps

module uart_peripheral #(
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

    // Serial lines
    output logic        tx,
    input  logic        rx,

    output logic        rx_ready,
    output logic [7:0]  rx_data
);

    uart_regs #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_core (
        .clk      (clk),
        .reset    (reset),
        .awaddr   (awaddr),
        .awvalid  (awvalid),
        .awready  (awready),
        .wdata    (wdata),
        .wstrb    (wstrb),
        .wvalid   (wvalid),
        .wready   (wready),
        .bresp    (bresp),
        .bvalid   (bvalid),
        .bready   (bready),
        .araddr   (araddr),
        .arvalid  (arvalid),
        .arready  (arready),
        .rdata    (rdata),
        .rresp    (rresp),
        .rvalid   (rvalid),
        .rready   (rready),
        .tx       (tx),
        .rx       (rx),
        .rx_ready (rx_ready),
        .rx_data  (rx_data)
    );

endmodule
