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
    mailbox          mon2drv;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (virtual soc_intf vif, mailbox gen2drv, mailbox drv2mon, mailbox mon2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2mon = drv2mon;
        this.mon2drv = mon2drv;
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
        int               done_tok;

        for (int i = 0; i < num_tests; i++) begin
            gen2drv.get(tr);

            $display("");
            $display("----------------------------------------------------------");
            $display("  TEST %0d: %s", i + 1, tr.test_name);
            $display("----------------------------------------------------------");
            tr.display("DRIVER");

            // --- Assert reset ---
            vif.reset   = 1;
            vif.gpio_in = tr.set_gpio_in;
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

            // --- Run for specified cycles & sample active signals ---
            tr.actual_timer_overflow = 0;
            begin
                bit saw_pwm_high = 0, saw_pwm_low = 0;
                repeat (tr.run_cycles) begin
                    @(posedge vif.clk);
                    if (vif.timer_overflow) tr.actual_timer_overflow = 1;
                    if (vif.pwm_out)        saw_pwm_high = 1;
                    if (!vif.pwm_out)       saw_pwm_low  = 1;
                end
                if (tr.check_pwm)
                    tr.actual_pwm_toggled = (saw_pwm_high && saw_pwm_low);
            end
            tr.actual_gpio_out = vif.gpio_out;

            // --- Forward transaction to Monitor ---
            drv2mon.put(tr);

            // --- Wait for Monitor to complete sampling before proceeding to next test ---
            mon2drv.get(done_tok);
        end
    endtask

endclass
