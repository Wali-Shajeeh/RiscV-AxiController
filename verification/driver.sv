// ============================================================================
//  Driver Class — applies stimulus to the DUT
// ============================================================================
//  Receives transactions from the Generator via gen2drv mailbox.
//  For each transaction the Driver:
//    1. Asserts hardware reset
//    2. Backdoor-loads the instruction and data memories
//    3. Releases reset and runs the specified number of clock cycles
//    4. Forwards the transaction to the Monitor via drv2mon mailbox
// ============================================================================

class driver;

    virtual soc_intf vif;
    mailbox          gen2drv;
    mailbox          drv2mon;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (virtual soc_intf vif, mailbox gen2drv, mailbox drv2mon);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2mon = drv2mon;
    endfunction

    // ---------------------------------------------------------------
    //  Initial reset
    // ---------------------------------------------------------------
    task reset_dut ();
        vif.reset = 1;
        @(posedge vif.clk);
        @(posedge vif.clk);
    endtask

    // ---------------------------------------------------------------
    //  Main run loop
    // ---------------------------------------------------------------
    task run (int num_tests);
        riscv_transaction tr;

        for (int i = 0; i < num_tests; i++) begin
            gen2drv.get(tr);

            $display("");
            $display("----------------------------------------------------------");
            $display("  TEST %0d: %s", i + 1, tr.test_name);
            $display("----------------------------------------------------------");
            tr.display("DRIVER");

            // --- Assert reset ---
            vif.reset = 1;
            @(posedge vif.clk);
            @(posedge vif.clk);

            // --- Backdoor: clear instruction memory with NOPs ---
            for (int j = 0; j < 1024; j++)
                top_tb.dut.u_instr_mem.mem[j] = 32'h00000013;

            // --- Backdoor: clear data memory ---
            for (int j = 0; j < 1024; j++)
                top_tb.dut.u_data_mem.mem[j] = 32'h00000000;

            // --- Backdoor: load program ---
            for (int j = 0; j < tr.program_hex.size(); j++)
                top_tb.dut.u_instr_mem.mem[j] = tr.program_hex[j];

            // --- Release reset ---
            @(posedge vif.clk);
            vif.reset = 0;

            // --- Run for specified cycles ---
            repeat (tr.run_cycles) @(posedge vif.clk);

            // --- Forward transaction to Monitor ---
            drv2mon.put(tr);
        end
    endtask

endclass
