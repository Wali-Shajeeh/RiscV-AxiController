// ============================================================================
//  Transaction Class — encapsulates one directed test case
// ============================================================================
//  Stimulus fields are set by the Generator.
//  Observed fields are filled in by the Monitor after the Driver executes
//  the test.  The Scoreboard compares the two sets to determine pass/fail.
// ============================================================================

class riscv_transaction;

    // ---------------------------------------------------------------
    //  Stimulus fields  (populated by Generator)
    // ---------------------------------------------------------------
    string       test_name;
    logic [31:0] program_hex [];       // instruction words to load
    int          run_cycles;           // clock cycles to run after reset release
    int          check_regs [];        // register-file indices to verify
    logic [31:0] exp_reg [0:31];       // expected register-file values
    int          check_mem_addrs [];   // data-memory word addresses to verify
    logic [31:0] check_mem_vals  [];   // expected data-memory values
    bit          check_pwm;            // should we check PWM toggling?
    int          pwm_wait_cycles;      // extra cycles to wait for PWM edges

    // ---------------------------------------------------------------
    //  Observed fields  (populated by Monitor)
    // ---------------------------------------------------------------
    logic [31:0] actual_reg [0:31];
    logic [31:0] actual_mem_vals [];
    bit          actual_pwm_toggled;

    // ---------------------------------------------------------------
    //  Display helper
    // ---------------------------------------------------------------
    function void display (string tag);
        $display("  [%s] %s  |  run_cycles=%0d  |  regs_to_check=%0d  |  mem_to_check=%0d",
                 tag, test_name, run_cycles, check_regs.size(), check_mem_addrs.size());
    endfunction

endclass
