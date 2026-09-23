// ============================================================================
//  RISC-V SoC — Modular Layered Testbench — Top Module
// ============================================================================
//
//  LAYERED STRUCTURE:
//  ┌──────────────────────────────────────────────────────┐
//  │  top_tb  (clock generation, DUT instantiation)       │
//  │  ├── soc_intf         (interface)                    │
//  │  ├── environment      (orchestrator)                 │
//  │  │   ├── generator    (builds test programs)         │
//  │  │   ├── driver       (load + run)                   │
//  │  │   ├── monitor      (sample DUT state)             │
//  │  │   └── scoreboard   (pass/fail tracking)           │
//  │  │                                                   │
//  │  │           ┌──────────────────────┐                │
//  │  │           │ updated_top_module2  │  (DUT)         │
//  │  │           └──────────────────────┘                │
//  │  └── AXI handshake monitor (background)              │
//  └──────────────────────────────────────────────────────┘
//
// ============================================================================

`timescale 1ns / 1ps

`include "environment.sv"

module top_tb;

    // ---------------------------------------------------------------
    //  Clock Generation — 100 MHz (10 ns period)
    // ---------------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    //  Interface
    // ---------------------------------------------------------------
    soc_intf intf (clk);

    // ---------------------------------------------------------------
    //  DUT: updated_top_module2 (single-cycle RISC-V SoC + AXI + PWM)
    // ---------------------------------------------------------------
    updated_top_module2 dut (
        .clk     (clk),
        .reset   (intf.reset),
        .pwm_out (intf.pwm_out)
    );

    // ---------------------------------------------------------------
    //  AXI handshake monitor (runs in background)
    // ---------------------------------------------------------------
    int axi_write_count, axi_read_count;

    always @(posedge clk) begin
        if (dut.axi_bvalid && dut.axi_bready)
            axi_write_count++;
        if (dut.axi_rvalid && dut.axi_rready)
            axi_read_count++;
    end

    // Debug: report when AXI adapter enters a non-IDLE state
    always @(posedge clk) begin
        if (!intf.reset && dut.u_axi_adapter.state == 1 &&
            dut.u_axi_adapter.state != dut.u_axi_adapter.next_state)
            $display("  [AXI-MON] AXI write handshake in progress at addr=0x%08h",
                     dut.alu_result);
    end

    // ---------------------------------------------------------------
    //  Main Test Flow
    // ---------------------------------------------------------------
    environment env;

    initial begin
        axi_write_count = 0;
        axi_read_count  = 0;

        // Create environment and run all tests
        env = new(intf);
        env.run();

        // AXI bus summary
        $display("");
        $display("----------------------------------------------------------");
        $display("  AXI BUS SUMMARY");
        $display("----------------------------------------------------------");
        $display("    Total AXI Writes completed: %0d", axi_write_count);
        $display("    Total AXI Reads  completed: %0d", axi_read_count);

        // Final scoreboard verdict
        env.scb.report();

        #10;
        $finish;
    end

endmodule
