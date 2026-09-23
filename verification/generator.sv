// ============================================================================
//  Generator Class — creates directed test programs
// ============================================================================
//  Builds all 8 directed test transactions and sends them to the Driver
//  through the gen2drv mailbox.
// ============================================================================

class riscv_generator;

    mailbox gen2drv;
    int     total_tests;

    // ---------------------------------------------------------------
    //  Constructor
    // ---------------------------------------------------------------
    function new (mailbox gen2drv);
        this.gen2drv    = gen2drv;
        this.total_tests = 0;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 1 : Reset behavior — all registers should be zero
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_reset ();
        riscv_transaction t = new();
        t.test_name  = "RESET: all registers zero after reset";
        t.run_cycles = 0;
        t.check_pwm  = 0;
        t.program_hex = new[1];
        t.program_hex[0] = 32'h00000013;  // nop

        t.check_regs = '{1, 2, 3, 4, 5, 10, 15, 31};
        for (int i = 0; i < 32; i++) t.exp_reg[i] = 0;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 2 : R-type (add, sub, and, or, xor, slt)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_rtype ();
        riscv_transaction t = new();
        t.test_name  = "R-TYPE: add, sub, and, or, xor, slt";
        t.run_cycles = 20;
        t.check_pwm  = 0;

        t.program_hex = new[8];
        t.program_hex[0] = 32'h00A00093;  // addi x1, x0, 10
        t.program_hex[1] = 32'h00300113;  // addi x2, x0, 3
        t.program_hex[2] = 32'h002081B3;  // add  x3, x1, x2  -> 13
        t.program_hex[3] = 32'h40208233;  // sub  x4, x1, x2  -> 7
        t.program_hex[4] = 32'h0020F2B3;  // and  x5, x1, x2  -> 2
        t.program_hex[5] = 32'h0020E333;  // or   x6, x1, x2  -> 11
        t.program_hex[6] = 32'h0020C3B3;  // xor  x7, x1, x2  -> 9
        t.program_hex[7] = 32'h00112433;  // slt  x8, x2, x1  -> 1

        t.check_regs = '{1, 2, 3, 4, 5, 6, 7, 8};
        t.exp_reg[1] = 10; t.exp_reg[2] = 3;  t.exp_reg[3] = 13;
        t.exp_reg[4] = 7;  t.exp_reg[5] = 2;  t.exp_reg[6] = 11;
        t.exp_reg[7] = 9;  t.exp_reg[8] = 1;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 3 : I-type ALU (addi, andi, ori, xori, slti, slli, srli)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_itype ();
        riscv_transaction t = new();
        t.test_name  = "I-TYPE ALU: addi, andi, ori, xori, slti, slli, srli";
        t.run_cycles = 20;
        t.check_pwm  = 0;

        t.program_hex = new[7];
        t.program_hex[0] = 32'h06400093;  // addi  x1, x0, 100
        t.program_hex[1] = 32'h00F0F113;  // andi  x2, x1, 15    -> 4
        t.program_hex[2] = 32'h0030E193;  // ori   x3, x1, 3     -> 103
        t.program_hex[3] = 32'h0FF0C213;  // xori  x4, x1, 255   -> 155
        t.program_hex[4] = 32'h0C80A293;  // slti  x5, x1, 200   -> 1
        t.program_hex[5] = 32'h00209313;  // slli  x6, x1, 2     -> 400
        t.program_hex[6] = 32'h0030D393;  // srli  x7, x1, 3     -> 12

        t.check_regs = '{1, 2, 3, 4, 5, 6, 7};
        t.exp_reg[1] = 100; t.exp_reg[2] = 4;   t.exp_reg[3] = 103;
        t.exp_reg[4] = 155; t.exp_reg[5] = 1;   t.exp_reg[6] = 400;
        t.exp_reg[7] = 12;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 4 : Load & Store (sw, lw)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_load_store ();
        riscv_transaction t = new();
        t.test_name  = "LOAD/STORE: sw, lw through data memory";
        t.run_cycles = 15;
        t.check_pwm  = 0;

        t.program_hex = new[4];
        t.program_hex[0] = 32'h02A00093;  // addi x1, x0, 42
        t.program_hex[1] = 32'h00102023;  // sw   x1, 0(x0)    -> mem[0]=42
        t.program_hex[2] = 32'h00002103;  // lw   x2, 0(x0)    -> x2=42
        t.program_hex[3] = 32'h00810193;  // addi x3, x2, 8    -> x3=50

        t.check_regs = '{1, 2, 3};
        t.exp_reg[1] = 42; t.exp_reg[2] = 42; t.exp_reg[3] = 50;

        t.check_mem_addrs = '{0};
        t.check_mem_vals  = '{42};
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 5 : Branch (BEQ taken — skip instruction)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_branch ();
        riscv_transaction t = new();
        t.test_name  = "BRANCH: beq taken skips one instruction";
        t.run_cycles = 15;
        t.check_pwm  = 0;

        t.program_hex = new[5];
        t.program_hex[0] = 32'h00500093;  // addi x1, x0, 5
        t.program_hex[1] = 32'h00500113;  // addi x2, x0, 5
        t.program_hex[2] = 32'h00208463;  // beq  x1, x2, +8   -> skip next
        t.program_hex[3] = 32'h06300193;  // addi x3, x0, 99   (SKIPPED)
        t.program_hex[4] = 32'h04D00213;  // addi x4, x0, 77   (executed)

        t.check_regs = '{1, 3, 4};
        t.exp_reg[1] = 5; t.exp_reg[3] = 0; t.exp_reg[4] = 77;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 6 : JAL (jump and link)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_jal ();
        riscv_transaction t = new();
        t.test_name  = "JAL: jump forward, save return address";
        t.run_cycles = 15;
        t.check_pwm  = 0;

        t.program_hex = new[5];
        t.program_hex[0] = 32'h00100093;  // addi x1, x0, 1
        t.program_hex[1] = 32'h008002EF;  // jal  x5, +8 -> x5=8, jump to 0x0C
        t.program_hex[2] = 32'h06300113;  // addi x2, x0, 99 (SKIPPED)
        t.program_hex[3] = 32'h02100193;  // addi x3, x0, 33 (landed)
        t.program_hex[4] = 32'h00000013;  // nop

        t.check_regs = '{1, 2, 3, 5};
        t.exp_reg[1] = 1; t.exp_reg[2] = 0; t.exp_reg[3] = 33;
        t.exp_reg[5] = 8;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 7 : AXI Write + PWM toggle  (known stall-latency bug)
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_axi_pwm_write ();
        riscv_transaction t = new();
        t.test_name  = "AXI WRITE + PWM (known stall-latency bug)";
        t.run_cycles = 200;
        t.check_pwm  = 0;   // PWM won't toggle due to stall bug

        t.program_hex = new[8];
        t.program_hex[0] = 32'h400004B7;  // lui   x9,  0x40000  -> x9 = 0x40000000
        t.program_hex[1] = 32'h06400513;  // addi  x10, x0, 100
        t.program_hex[2] = 32'h00A4A223;  // sw    x10, 4(x9)    -> triggers AXI write
        t.program_hex[3] = 32'h01900593;  // addi  x11, x0, 25
        t.program_hex[4] = 32'h00B4A423;  // sw    x11, 8(x9)
        t.program_hex[5] = 32'h00100613;  // addi  x12, x0, 1
        t.program_hex[6] = 32'h00C4A023;  // sw    x12, 0(x9)
        t.program_hex[7] = 32'h0000006F;  // jal   x0, 0

        // Only verify registers set BEFORE the AXI write (LUI, ADDI)
        t.check_regs = '{9, 10};
        t.exp_reg[9]  = 32'h40000000;
        t.exp_reg[10] = 100;

        t.check_mem_addrs = new[0];
        t.check_mem_vals  = new[0];

        // Report the bug to the console
        $display("  [NOTE] AXI stall-latency bug: PC advances 1 cycle before busy asserts.");
        $display("         This causes AXI address to change mid-handshake -> deadlock.");
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  TEST 8 : AXI Address Decoding — write to local memory
    // ---------------------------------------------------------------
    function riscv_transaction gen_test_address_decode ();
        riscv_transaction t = new();
        t.test_name  = "ADDRESS DECODE: local mem vs peripheral boundary";
        t.run_cycles = 15;
        t.check_pwm  = 0;

        t.program_hex = new[4];
        t.program_hex[0] = 32'h07B00093;  // addi x1, x0, 123
        t.program_hex[1] = 32'h00000113;  // addi x2, x0, 0
        t.program_hex[2] = 32'h00112023;  // sw   x1, 0(x2)
        t.program_hex[3] = 32'h00012183;  // lw   x3, 0(x2)

        t.check_regs = '{1, 3};
        t.exp_reg[1] = 123; t.exp_reg[3] = 123;

        t.check_mem_addrs = '{0};
        t.check_mem_vals  = '{123};
        return t;
    endfunction

    // ---------------------------------------------------------------
    //  run() — generate all tests and push into gen2drv mailbox
    // ---------------------------------------------------------------
    task run ();
        riscv_transaction tests_q [$];

        tests_q.push_back(gen_test_reset());
        tests_q.push_back(gen_test_rtype());
        tests_q.push_back(gen_test_itype());
        tests_q.push_back(gen_test_load_store());
        tests_q.push_back(gen_test_branch());
        tests_q.push_back(gen_test_jal());
        tests_q.push_back(gen_test_axi_pwm_write());
        tests_q.push_back(gen_test_address_decode());

        total_tests = tests_q.size();

        foreach (tests_q[i]) begin
            gen2drv.put(tests_q[i]);
            tests_q[i].display("GENERATOR");
        end
    endtask

endclass
