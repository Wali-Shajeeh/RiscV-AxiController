// ============================================================================
//  Scoreboard Class — verifies expected vs. actual results
// ============================================================================
//  Receives observed transactions from the Monitor via mon2scb mailbox.
//  Compares registers, data memory, and PWM status against expected values.
//  Tracks cumulative pass/fail statistics and prints a final verdict.
// ============================================================================

class scoreboard;

    mailbox mon2scb;
    int     total_pass;
    int     total_fail;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (mailbox mon2scb);
        this.mon2scb   = mon2scb;
        this.total_pass = 0;
        this.total_fail = 0;
    endfunction

    // ---------------------------------------------------------------
    //  Main run loop
    // ---------------------------------------------------------------
    task run (int num_tests);
        riscv_transaction tr;

        for (int i = 0; i < num_tests; i++) begin
            mon2scb.get(tr);
            $display("  [CHECKER] Verifying: %s", tr.test_name);
            check_registers(tr);
            check_memory(tr);
            check_pwm(tr);
            check_gpio(tr);
            check_timer(tr);
        end
    endtask

    // ---------------------------------------------------------------
    //  Register comparison
    // ---------------------------------------------------------------
    function void check_registers (riscv_transaction tr);
        int idx;
        for (int i = 0; i < tr.check_regs.size(); i++) begin
            idx = tr.check_regs[i];
            if (tr.actual_reg[idx] !== tr.exp_reg[idx]) begin
                $display("    [FAIL] x%0d = 0x%08h, expected 0x%08h",
                         idx, tr.actual_reg[idx], tr.exp_reg[idx]);
                total_fail++;
            end else begin
                $display("    [PASS] x%0d = 0x%08h", idx, tr.actual_reg[idx]);
                total_pass++;
            end
        end
    endfunction

    // ---------------------------------------------------------------
    //  Data-memory comparison
    // ---------------------------------------------------------------
    function void check_memory (riscv_transaction tr);
        int idx;
        for (int i = 0; i < tr.check_mem_addrs.size(); i++) begin
            idx = tr.check_mem_addrs[i];
            if (tr.actual_mem_vals[i] !== tr.check_mem_vals[i]) begin
                $display("    [FAIL] mem[%0d] = 0x%08h, expected 0x%08h",
                         idx, tr.actual_mem_vals[i], tr.check_mem_vals[i]);
                total_fail++;
            end else begin
                $display("    [PASS] mem[%0d] = 0x%08h", idx, tr.actual_mem_vals[i]);
                total_pass++;
            end
        end
    endfunction

    // ---------------------------------------------------------------
    //  PWM toggling check
    // ---------------------------------------------------------------
    function void check_pwm (riscv_transaction tr);
        if (tr.check_pwm) begin
            if (tr.actual_pwm_toggled) begin
                $display("    [PASS] PWM toggled (saw HIGH and LOW)");
                total_pass++;
            end else begin
                $display("    [FAIL] PWM did NOT toggle");
                total_fail++;
            end
        end
    endfunction

    // ---------------------------------------------------------------
    //  GPIO output check
    // ---------------------------------------------------------------
    function void check_gpio (riscv_transaction tr);
        if (tr.check_gpio_out) begin
            if (tr.actual_gpio_out === tr.exp_gpio_out) begin
                $display("    [PASS] gpio_out = 0x%08h", tr.actual_gpio_out);
                total_pass++;
            end else begin
                $display("    [FAIL] gpio_out = 0x%08h, expected 0x%08h",
                         tr.actual_gpio_out, tr.exp_gpio_out);
                total_fail++;
            end
        end
    endfunction

    // ---------------------------------------------------------------
    //  Timer overflow check
    // ---------------------------------------------------------------
    function void check_timer (riscv_transaction tr);
        if (tr.check_timer_overflow) begin
            if (tr.actual_timer_overflow) begin
                $display("    [PASS] Timer overflow pulse detected");
                total_pass++;
            end else begin
                $display("    [FAIL] Timer overflow NOT detected");
                total_fail++;
            end
        end
    endfunction

    // ---------------------------------------------------------------
    //  Final report
    // ---------------------------------------------------------------
    function void report ();
        $display("");
        $display("==========================================================");
        $display("  SCOREBOARD:  %0d PASSED  |  %0d FAILED", total_pass, total_fail);
        $display("==========================================================");
        if (total_fail == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");
        $display("==========================================================");
    endfunction

endclass
