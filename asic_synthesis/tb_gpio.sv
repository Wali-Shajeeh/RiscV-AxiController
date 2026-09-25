// ============================================================================
//  GPIO Peripheral — Standalone Directed Self-Checking Testbench
// ============================================================================
//  Tests:
//    1.  Reset — all registers zero, gpio_out = 0
//    2.  Write Direction Register (0x00) — set some bits as output
//    3.  Write Output Register (0x04) — drive output pins
//    4.  Read Direction Register — verify readback
//    5.  Read Output Register — verify readback
//    6.  Read Input Register (0x08) — verify sampled gpio_in
//    7.  Output masking — gpio_out = out_reg & dir_reg
//    8.  Input changes reflected in read data
//    9.  Write to read-only input register (0x08) — ignored
//   10.  Invalid register offset — returns 0
//   11.  Full 32-bit direction/output test
//   12.  Direction change masks output dynamically
// ============================================================================

`timescale 1ns / 1ps

module tb_gpio;

    // ---------------------------------------------------------------
    //  Clock & Reset
    // ---------------------------------------------------------------
    logic        clk;
    logic        reset;

    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // ---------------------------------------------------------------
    //  AXI4-Lite Signals
    // ---------------------------------------------------------------
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // ---------------------------------------------------------------
    //  GPIO Signals
    // ---------------------------------------------------------------
    logic [31:0] gpio_out;
    logic [31:0] gpio_in;

    // ---------------------------------------------------------------
    //  DUT
    // ---------------------------------------------------------------
    gpio_peripheral dut (
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
        .gpio_out (gpio_out),
        .gpio_in  (gpio_in)
    );

    // ---------------------------------------------------------------
    //  Scoreboard
    // ---------------------------------------------------------------
    int total_pass = 0;
    int total_fail = 0;

    // ---------------------------------------------------------------
    //  AXI4-Lite Write Task
    // ---------------------------------------------------------------
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
        // Address phase
        @(posedge clk);
        awaddr  <= addr;
        awvalid <= 1'b1;
        wdata   <= 32'b0;   // not valid yet
        wvalid  <= 1'b0;
        wstrb   <= 4'hF;
        bready  <= 1'b0;

        // Wait for awready
        do @(posedge clk); while (!awready);
        awvalid <= 1'b0;

        // Data phase
        wdata  <= data;
        wvalid <= 1'b1;
        do @(posedge clk); while (!wready);
        wvalid <= 1'b0;

        // Response phase
        bready <= 1'b1;
        do @(posedge clk); while (!bvalid);
        bready <= 1'b0;

        @(posedge clk);
    endtask

    // ---------------------------------------------------------------
    //  AXI4-Lite Read Task
    // ---------------------------------------------------------------
    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
        // Address phase
        @(posedge clk);
        araddr  <= addr;
        arvalid <= 1'b1;
        rready  <= 1'b0;

        do @(posedge clk); while (!arready);
        arvalid <= 1'b0;

        // Data phase
        rready <= 1'b1;
        do @(posedge clk); while (!rvalid);
        data = rdata;
        rready <= 1'b0;

        @(posedge clk);
    endtask

    // ---------------------------------------------------------------
    //  Check helper
    // ---------------------------------------------------------------
    task automatic check(input string label, input logic [31:0] actual, input logic [31:0] expected);
        if (actual === expected) begin
            $display("    [PASS] %s = 0x%08h", label, actual);
            total_pass++;
        end else begin
            $display("    [FAIL] %s = 0x%08h, expected 0x%08h", label, actual, expected);
            total_fail++;
        end
    endtask

    // ---------------------------------------------------------------
    //  Test Stimulus
    // ---------------------------------------------------------------
    logic [31:0] rd_data;

    initial begin
        // Init all signals
        awaddr  = 0; awvalid = 0;
        wdata   = 0; wstrb   = 4'hF; wvalid = 0;
        bready  = 0;
        araddr  = 0; arvalid = 0;
        rready  = 0;
        gpio_in = 32'b0;

        $display("");
        $display("==========================================================");
        $display("  GPIO Peripheral — Directed Self-Checking Testbench");
        $display("==========================================================");

        // ---- Reset ----
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // =============================================================
        //  TEST 1: Reset state
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 1: Reset — registers and gpio_out should be zero");
        $display("----------------------------------------------------------");
        check("gpio_out", gpio_out, 32'h0);
        axi_read(32'h40020000, rd_data);
        check("DIR_REG read", rd_data, 32'h0);
        axi_read(32'h40020004, rd_data);
        check("OUT_REG read", rd_data, 32'h0);

        // =============================================================
        //  TEST 2: Write Direction Register
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 2: Write DIR_REG = 0x0000_00FF (lower 8 bits output)");
        $display("----------------------------------------------------------");
        axi_write(32'h40020000, 32'h000000FF);
        axi_read(32'h40020000, rd_data);
        check("DIR_REG readback", rd_data, 32'h000000FF);

        // =============================================================
        //  TEST 3: Write Output Register
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 3: Write OUT_REG = 0x0000_00A5");
        $display("----------------------------------------------------------");
        axi_write(32'h40020004, 32'h000000A5);
        axi_read(32'h40020004, rd_data);
        check("OUT_REG readback", rd_data, 32'h000000A5);
        // gpio_out should be out_reg & dir_reg = 0xA5 & 0xFF = 0xA5
        @(posedge clk);
        check("gpio_out (masked)", gpio_out, 32'h000000A5);

        // =============================================================
        //  TEST 4: Read Input Register
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 4: Read IN_REG — drive gpio_in = 0xDEAD_BEEF");
        $display("----------------------------------------------------------");
        gpio_in = 32'hDEADBEEF;
        @(posedge clk);
        axi_read(32'h40020008, rd_data);
        check("IN_REG read", rd_data, 32'hDEADBEEF);

        // =============================================================
        //  TEST 5: Output masking — dir_reg masks out_reg
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 5: Output masking — OUT=0xFFFF_FFFF, DIR=0x00FF");
        $display("----------------------------------------------------------");
        axi_write(32'h40020004, 32'hFFFFFFFF);
        @(posedge clk);
        // dir_reg = 0x000000FF, so gpio_out = 0x000000FF
        check("gpio_out (masked)", gpio_out, 32'h000000FF);

        // =============================================================
        //  TEST 6: Input changes reflected dynamically
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 6: Input changes — gpio_in toggled");
        $display("----------------------------------------------------------");
        gpio_in = 32'h12345678;
        @(posedge clk);
        axi_read(32'h40020008, rd_data);
        check("IN_REG (changed)", rd_data, 32'h12345678);

        gpio_in = 32'h00000000;
        @(posedge clk);
        axi_read(32'h40020008, rd_data);
        check("IN_REG (zeroed)", rd_data, 32'h00000000);

        // =============================================================
        //  TEST 7: Write to read-only IN register — should be ignored
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 7: Write to IN_REG (0x08) — should be ignored");
        $display("----------------------------------------------------------");
        gpio_in = 32'hAAAAAAAA;
        axi_write(32'h40020008, 32'hBAD0FACE);
        @(posedge clk);
        axi_read(32'h40020008, rd_data);
        check("IN_REG after ignored write", rd_data, 32'hAAAAAAAA);
        // DIR and OUT should be unchanged
        axi_read(32'h40020000, rd_data);
        check("DIR_REG unchanged", rd_data, 32'h000000FF);
        axi_read(32'h40020004, rd_data);
        check("OUT_REG unchanged", rd_data, 32'hFFFFFFFF);

        // =============================================================
        //  TEST 8: Invalid register offset — returns 0
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 8: Read invalid offset 0x0C — should return 0");
        $display("----------------------------------------------------------");
        axi_read(32'h4002000C, rd_data);
        check("Invalid offset read", rd_data, 32'h00000000);

        // =============================================================
        //  TEST 9: Full 32-bit direction and output
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 9: Full 32-bit — DIR=all output, OUT=0xCAFEBABE");
        $display("----------------------------------------------------------");
        axi_write(32'h40020000, 32'hFFFFFFFF);  // all output
        axi_write(32'h40020004, 32'hCAFEBABE);
        @(posedge clk);
        check("gpio_out (full 32b)", gpio_out, 32'hCAFEBABE);

        // =============================================================
        //  TEST 10: Direction change masks output dynamically
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 10: Change DIR to 0xF0F0_F0F0 — output re-masked");
        $display("----------------------------------------------------------");
        axi_write(32'h40020000, 32'hF0F0F0F0);
        @(posedge clk);
        // gpio_out = 0xCAFEBABE & 0xF0F0F0F0 = 0xC0F0B0B0
        check("gpio_out (re-masked)", gpio_out, 32'hC0F0B0B0);

        // =============================================================
        //  TEST 11: Reset clears everything
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 11: Reset clears all registers");
        $display("----------------------------------------------------------");
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        check("gpio_out after reset", gpio_out, 32'h0);
        axi_read(32'h40020000, rd_data);
        check("DIR_REG after reset", rd_data, 32'h0);
        axi_read(32'h40020004, rd_data);
        check("OUT_REG after reset", rd_data, 32'h0);

        // =============================================================
        //  TEST 12: AXI write response is OKAY (bresp = 2'b00)
        // =============================================================
        $display("");
        $display("----------------------------------------------------------");
        $display("  TEST 12: AXI response codes");
        $display("----------------------------------------------------------");
        axi_write(32'h40020000, 32'h1);
        check("bresp (write)", {30'b0, bresp}, 32'h0);
        axi_read(32'h40020000, rd_data);
        check("rresp (read)", {30'b0, rresp}, 32'h0);

        // =============================================================
        //  Final Scoreboard
        // =============================================================
        $display("");
        $display("==========================================================");
        $display("  SCOREBOARD:  %0d PASSED  |  %0d FAILED", total_pass, total_fail);
        $display("==========================================================");
        if (total_fail == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("==========================================================");

        #10;
        $finish;
    end

endmodule
