// ============================================================================
//  Environment Class — assembles and orchestrates all TB layers
// ============================================================================
//  Creates the three mailboxes, instantiates the Generator, Driver, Monitor,
//  and Scoreboard, and wires them together.  The run() task drives the full
//  test sequence:
//    1. Generator produces all transactions (sequentially, before fork)
//    2. Driver, Monitor, Scoreboard run concurrently inside fork/join
// ============================================================================

`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"

class environment;

    // ---------------------------------------------------------------
    //  Components
    // ---------------------------------------------------------------
    riscv_generator gen;
    driver          drv;
    monitor         mon;
    scoreboard      scb;

    // ---------------------------------------------------------------
    //  Mailboxes
    // ---------------------------------------------------------------
    mailbox gen2drv;
    mailbox drv2mon;
    mailbox mon2scb;

    // ---------------------------------------------------------------
    //  Virtual interface handle
    // ---------------------------------------------------------------
    virtual soc_intf vif;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (virtual soc_intf vif);
        this.vif = vif;

        gen2drv = new();
        drv2mon = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv, drv2mon);
        mon = new(vif, drv2mon, mon2scb);
        scb = new(mon2scb);
    endfunction

    // ---------------------------------------------------------------
    //  run() — execute the full verification sequence
    // ---------------------------------------------------------------
    task run ();
        // 1. Generate all directed tests (populates gen2drv mailbox)
        gen.run();

        // 2. Print test header
        $display("");
        $display("==========================================================");
        $display("  RISC-V SoC — Modular Layered Directed Testbench");
        $display("  DUT: updated_top_module2 (single-cycle + AXI + PWM)");
        $display("  Total Tests: %0d", gen.total_tests);
        $display("==========================================================");

        // 3. Launch Driver, Monitor, Scoreboard concurrently
        fork
            drv.run(gen.total_tests);
            mon.run(gen.total_tests);
            scb.run(gen.total_tests);
        join
    endtask

endclass
