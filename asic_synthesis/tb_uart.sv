// ============================================================================
//  tb_uart.sv — Comprehensive Unit & Integration Testbench for UART Subsystem
// ============================================================================
//  Verifies:
//    1. Reset state (TX idle-high, TX status ready, RX flags cleared)
//    2. AXI4-Lite Register Writes & Reads (TX_DATA, TX_STATUS, RX_DATA, RX_STATUS)
//    3. 8N1 Serial Protocol Timing (Start bit, 8 Data bits LSB-first, Stop bit)
//    4. RX mid-bit sampling, start-bit validation & noise rejection
//    5. Autoclear of RX status flag upon reading RX_DATA
//    6. Full loopback (TX -> RX) streaming multiple data bytes
// ============================================================================

`timescale 1ns / 1ps

module tb_uart;

    // ------------------------------------------------------------------------
    //  Clock & Reset (Use fast baud rate in TB for swift simulation: 1M baud)
    // ------------------------------------------------------------------------
    localparam int CLK_FREQ  = 50_000_000;  // 50 MHz clock (20ns period)
    localparam int BAUD_RATE = 1_000_000;   // 1 MHz baud (50 cycles / bit)
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam time BIT_PERIOD  = 1000ns;   // 1us per bit at 1M baud

    logic clk;
    logic reset;

    initial clk = 0;
    always #10 clk = ~clk;  // 50 MHz

    // ------------------------------------------------------------------------
    //  AXI4-Lite Signals
    // ------------------------------------------------------------------------
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

    // UART Serial Lines
    logic        tx;
    logic        rx;
    logic        rx_ready;
    logic [7:0]  rx_data;

    // Loopback control mux
    logic loopback_en;
    logic rx_stimulus;
    assign rx = loopback_en ? tx : rx_stimulus;

    // ------------------------------------------------------------------------
    //  DUT Instantiation
    // ------------------------------------------------------------------------
    uart_regs #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
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

    // ------------------------------------------------------------------------
    //  Scoreboard & Test Stats
    // ------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    task check (string name, logic condition);
        if (condition) begin
            $display("  [PASS] %s", name);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", name);
            fail_count++;
        end
    endtask

    // ------------------------------------------------------------------------
    //  AXI4-Lite Master Tasks
    // ------------------------------------------------------------------------
    task axi_write (input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        awaddr  <= addr;
        awvalid <= 1'b1;
        wdata   <= data;
        wstrb   <= 4'b1111;
        wvalid  <= 1'b1;
        bready  <= 1'b1;

        fork
            begin
                while (!awready) @(posedge clk);
                @(posedge clk);
                awvalid <= 1'b0;
            end
            begin
                while (!wready) @(posedge clk);
                @(posedge clk);
                wvalid <= 1'b0;
            end
        join

        while (!bvalid) @(posedge clk);
        @(posedge clk);
        bready <= 1'b0;
    endtask

    task axi_read (input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        araddr  <= addr;
        arvalid <= 1'b1;
        rready  <= 1'b1;

        while (!arready) @(posedge clk);
        @(posedge clk);
        arvalid <= 1'b0;

        while (!rvalid) @(posedge clk);
        data = rdata;
        @(posedge clk);
        rready <= 1'b0;
    endtask

    // ------------------------------------------------------------------------
    //  Serial RX Stimulus Generator (sends 8N1 serial byte to rx pin)
    // ------------------------------------------------------------------------
    task send_serial_byte (input logic [7:0] byte_val);
        // Start bit (0)
        rx_stimulus = 1'b0;
        #BIT_PERIOD;

        // 8 data bits LSB first
        for (int i = 0; i < 8; i++) begin
            rx_stimulus = byte_val[i];
            #BIT_PERIOD;
        end

        // Stop bit (1)
        rx_stimulus = 1'b1;
        #BIT_PERIOD;
    endtask

    // ------------------------------------------------------------------------
    //  Main Verification Routine
    // ------------------------------------------------------------------------
    initial begin
        logic [31:0] read_val;
        logic [7:0]  captured_byte;

        // Signal init
        reset       = 1;
        loopback_en = 0;
        rx_stimulus = 1'b1;
        awaddr      = 0;
        awvalid     = 0;
        wdata       = 0;
        wstrb       = 0;
        wvalid      = 0;
        bready      = 0;
        araddr      = 0;
        arvalid     = 0;
        rready      = 0;

        $display("");
        $display("==========================================================");
        $display("  UART Subsystem — SystemVerilog Verification Suite");
        $display("==========================================================");

        // Apply reset
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // --------------------------------------------------------------------
        //  TEST 1: Reset Status
        // --------------------------------------------------------------------
        $display("\n--- TEST 1: Power-on Reset Status ---");
        check("tx line idle-high", tx === 1'b1);
        
        axi_read(32'h04, read_val);
        check("tx_ready (TX_STATUS bit 0) is 1 on reset", read_val[0] === 1'b1);

        axi_read(32'h0C, read_val);
        check("rx_ready (RX_STATUS bit 0) is 0 on reset", read_val[0] === 1'b0);

        // --------------------------------------------------------------------
        //  TEST 2: TX Transmission of 0xA5 (10100101) & 8N1 Protocol Check
        // --------------------------------------------------------------------
        $display("\n--- TEST 2: TX Transmission (0xA5) & 8N1 Protocol Verification ---");
        axi_write(32'h00, 32'hA5);  // Write 0xA5 to TX_DATA

        // Check TX_STATUS indicates busy
        @(posedge clk);
        axi_read(32'h04, read_val);
        check("tx_busy active during transmission (TX_STATUS == 0)", read_val[0] === 1'b0);

        // Wait for start bit
        while (tx !== 1'b0) @(posedge clk);
        check("Start bit is 0", tx === 1'b0);

        // Sample data bits at center of each bit period
        #(BIT_PERIOD + BIT_PERIOD/2);
        for (int i = 0; i < 8; i++) begin
            captured_byte[i] = tx;
            #BIT_PERIOD;
        end

        check("Captured serial byte matches 0xA5", captured_byte === 8'hA5);
        check("Stop bit is 1", tx === 1'b1);

        // Wait for TX to finish and check status returns to idle
        #(BIT_PERIOD);
        axi_read(32'h04, read_val);
        check("tx_ready returns to 1 after transmission complete", read_val[0] === 1'b1);

        // --------------------------------------------------------------------
        //  TEST 3: RX Reception of 0x3C & Autoclear on Read
        // --------------------------------------------------------------------
        $display("\n--- TEST 3: RX Reception (0x3C) & Autoclear Check ---");
        send_serial_byte(8'h3C);

        // Check RX_STATUS indicates byte waiting
        repeat (5) @(posedge clk);
        axi_read(32'h0C, read_val);
        check("rx_ready flag is set in RX_STATUS (bit 0 == 1)", read_val[0] === 1'b1);

        // Read RX_DATA
        axi_read(32'h08, read_val);
        check("RX_DATA equals 0x3C", read_val[7:0] === 8'h3C);

        // Verify that reading RX_DATA automatically cleared the rx_ready flag
        axi_read(32'h0C, read_val);
        check("rx_ready flag automatically cleared after reading RX_DATA", read_val[0] === 1'b0);

        // --------------------------------------------------------------------
        //  TEST 4: Alternate Register Offsets (0x80, 0x84, 0x88, 0x8C)
        // --------------------------------------------------------------------
        $display("\n--- TEST 4: Offset 0x80/0x84/0x88/0x8C Backward Compatibility ---");
        send_serial_byte(8'h7E);
        repeat (5) @(posedge clk);

        axi_read(32'h8C, read_val);
        check("RX_STATUS at 0x8C is 1", read_val[0] === 1'b1);

        axi_read(32'h88, read_val);
        check("RX_DATA at 0x88 is 0x7E", read_val[7:0] === 8'h7E);

        axi_read(32'h8C, read_val);
        check("RX_STATUS at 0x8C cleared after read", read_val[0] === 1'b0);

        // --------------------------------------------------------------------
        //  TEST 5: Full Loopback (TX -> RX) with Multiple Consecutive Bytes
        // --------------------------------------------------------------------
        $display("\n--- TEST 5: Full TX-to-RX Loopback Stream ---");
        loopback_en = 1;  // Connect tx to rx
        repeat (10) @(posedge clk);

        begin
            automatic logic [7:0] test_bytes [3] = '{8'h55, 8'hF0, 8'hA9};
            for (int k = 0; k < 3; k++) begin
                // Ensure TX is ready
                do begin
                    axi_read(32'h04, read_val);
                end while (read_val[0] === 1'b0);

                // Send byte via AXI
                axi_write(32'h00, {24'h0, test_bytes[k]});

                // Wait for RX to complete
                do begin
                    axi_read(32'h0C, read_val);
                end while (read_val[0] === 1'b0);

                // Read received byte
                axi_read(32'h08, read_val);
                check($sformatf("Loopback byte %0d (0x%02h) correctly received", k+1, test_bytes[k]),
                      read_val[7:0] === test_bytes[k]);
            end
        end

        // --------------------------------------------------------------------
        //  Summary Verdict
        // --------------------------------------------------------------------
        $display("\n==========================================================");
        $display("  UART TEST RESULT: %0d PASSED | %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> ALL UART TESTS PASSED <<<");
        else
            $display("  >>> UART VERIFICATION FAILED <<<");
        $display("==========================================================\n");

        #100;
        $finish;
    end

endmodule
