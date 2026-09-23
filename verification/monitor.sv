// ============================================================================
//  Monitor Class — observes DUT state after each test
// ============================================================================
//  Waits for the Driver to finish a test (via drv2mon mailbox), then:
//    1. Samples the register file and data memory through backdoor access
//    2. Optionally checks PWM toggling
//    3. Fills the transaction's actual_* fields
//    4. Sends the observed transaction to the Scoreboard via mon2scb mailbox
// ============================================================================

class monitor;

    virtual soc_intf vif;
    mailbox          drv2mon;
    mailbox          mon2scb;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (virtual soc_intf vif, mailbox drv2mon, mailbox mon2scb);
        this.vif     = vif;
        this.drv2mon = drv2mon;
        this.mon2scb = mon2scb;
    endfunction

    // ---------------------------------------------------------------
    //  Main run loop
    // ---------------------------------------------------------------
    task run (int num_tests);
        riscv_transaction tr;

        for (int i = 0; i < num_tests; i++) begin
            drv2mon.get(tr);

            // --- Sample register file ---
            for (int j = 0; j < tr.check_regs.size(); j++) begin
                int idx;
                idx = tr.check_regs[j];
                if (idx == 0)
                    tr.actual_reg[idx] = 32'b0;
                else
                    tr.actual_reg[idx] = top_tb.dut.u_reg_file.registers[idx];
            end

            // --- Sample data memory ---
            tr.actual_mem_vals = new[tr.check_mem_addrs.size()];
            for (int j = 0; j < tr.check_mem_addrs.size(); j++) begin
                tr.actual_mem_vals[j] = top_tb.dut.u_data_mem.mem[tr.check_mem_addrs[j]];
            end

            // --- Check PWM toggling ---
            if (tr.check_pwm) begin
                bit saw_high, saw_low;
                saw_high = 0;
                saw_low  = 0;
                for (int j = 0; j < tr.pwm_wait_cycles; j++) begin
                    @(posedge vif.clk);
                    if (vif.pwm_out)  saw_high = 1;
                    if (!vif.pwm_out) saw_low  = 1;
                    if (saw_high && saw_low) break;
                end
                tr.actual_pwm_toggled = (saw_high && saw_low);
            end

            tr.display("MONITOR");

            // --- Forward to Scoreboard ---
            mon2scb.put(tr);
        end
    endtask

endclass
