// ============================================================================
//  RISC-V Single-Cycle Core — Simple Layered Testbench
// ============================================================================
//
//  LAYERED STRUCTURE:
//
//   tb_top (module)
//    ├── DUT: riscv_core
//    ├── Generator class  → builds test programs
//    ├── Driver class     → loads program, applies reset, runs clocks
//    ├── Checker class    → reads DUT state, compares expected vs actual
//    └── Environment class → ties gen + drv + chk, runs all tests
//
//  Backdoor access to DUT internals is done via module-level tasks/functions
//  that use hierarchical references (dut.u_reg_file.registers, etc.)
//
// ============================================================================

`timescale 1ns / 1ps


// ============================================================================
//  Transaction: one test case
// ============================================================================
class riscv_transaction;
    string       test_name;
    logic [31:0] program_hex [];       // instruction words to load
    int          run_cycles;           // clocks to run after reset release
    logic [31:0] exp_reg [0:31];       // expected register file values
    int          check_regs [];        // which register indices to verify
    int          check_mem_addrs [];   // data-memory word-addresses to verify
    logic [31:0] check_mem_vals  [];   // expected values at those addresses
endclass


// ============================================================================
//  Generator: creates test programs
// ============================================================================
class riscv_generator;

    riscv_transaction tests [$];

    // ---------------------------------------------------------------
    //  Test 1: R-type (ADD, SUB, AND, OR, XOR, SLT)
    // ---------------------------------------------------------------
    function void gen_test_rtype();
        riscv_transaction t = new();
        t.test_name  = "R-TYPE (add, sub, and, or, xor, slt)";
        t.run_cycles = 20;
        t.program_hex = new[8];
        t.program_hex[0] = 32'h00A00093;  // addi x1, x0, 10
        t.program_hex[1] = 32'h00300113;  // addi x2, x0, 3
        t.program_hex[2] = 32'h002081B3;  // add  x3, x1, x2  → 13
        t.program_hex[3] = 32'h40208233;  // sub  x4, x1, x2  → 7
        t.program_hex[4] = 32'h002092B3;  // and  x5, x1, x2  → 2
        t.program_hex[5] = 32'h0020E333;  // or   x6, x1, x2  → 11
        t.program_hex[6] = 32'h0020C3B3;  // xor  x7, x1, x2  → 9
        t.program_hex[7] = 32'h0011A433;  // slt  x8, x2, x1  → 1

        t.check_regs = '{1, 2, 3, 4, 5, 6, 7, 8};
        t.exp_reg[1] = 10; t.exp_reg[2] = 3;  t.exp_reg[3] = 13;
        t.exp_reg[4] = 7;  t.exp_reg[5] = 2;  t.exp_reg[6] = 11;
        t.exp_reg[7] = 9;  t.exp_reg[8] = 1;

        t.check_mem_addrs = '{};
        t.check_mem_vals  = '{};
        tests.push_back(t);
    endfunction

    // ---------------------------------------------------------------
    //  Test 2: I-type ALU (ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI)
    // ---------------------------------------------------------------
    function void gen_test_itype();
        riscv_transaction t = new();
        t.test_name  = "I-TYPE ALU (addi, andi, ori, xori, slti, slli, srli)";
        t.run_cycles = 20;
        t.program_hex = new[7];
        t.program_hex[0] = 32'h06400093;  // addi  x1, x0, 100
        t.program_hex[1] = 32'h00F0F113;  // andi  x2, x1, 15    → 4
        t.program_hex[2] = 32'h0030E193;  // ori   x3, x1, 3     → 103
        t.program_hex[3] = 32'h0FF0C213;  // xori  x4, x1, 255   → 155
        t.program_hex[4] = 32'h0C80A293;  // slti  x5, x1, 200   → 1
        t.program_hex[5] = 32'h00209313;  // slli  x6, x1, 2     → 400
        t.program_hex[6] = 32'h0030D393;  // srli  x7, x1, 3     → 12

        t.check_regs = '{1, 2, 3, 4, 5, 6, 7};
        t.exp_reg[1] = 100; t.exp_reg[2] = 4;   t.exp_reg[3] = 103;
        t.exp_reg[4] = 155; t.exp_reg[5] = 1;   t.exp_reg[6] = 400;
        t.exp_reg[7] = 12;

        t.check_mem_addrs = '{};
        t.check_mem_vals  = '{};
        tests.push_back(t);
    endfunction

    // ---------------------------------------------------------------
    //  Test 3: Load / Store (SW, LW)
    // ---------------------------------------------------------------
    function void gen_test_load_store();
        riscv_transaction t = new();
        t.test_name  = "LOAD/STORE (sw, lw)";
        t.run_cycles = 15;
        t.program_hex = new[4];
        t.program_hex[0] = 32'h02A00093;  // addi x1, x0, 42
        t.program_hex[1] = 32'h00102023;  // sw   x1, 0(x0)    → mem[0]=42
        t.program_hex[2] = 32'h00002103;  // lw   x2, 0(x0)    → x2=42
        t.program_hex[3] = 32'h00810193;  // addi x3, x2, 8    → x3=50

        t.check_regs = '{1, 2, 3};
        t.exp_reg[1] = 42; t.exp_reg[2] = 42; t.exp_reg[3] = 50;

        t.check_mem_addrs = '{0};
        t.check_mem_vals  = '{42};
        tests.push_back(t);
    endfunction

    // ---------------------------------------------------------------
    //  Test 4: Branch (BEQ taken → skip one instruction)
    // ---------------------------------------------------------------
    function void gen_test_branch();
        riscv_transaction t = new();
        t.test_name  = "BRANCH (beq taken)";
        t.run_cycles = 15;
        t.program_hex = new[5];
        t.program_hex[0] = 32'h00500093;  // addi x1, x0, 5
        t.program_hex[1] = 32'h00500113;  // addi x2, x0, 5
        t.program_hex[2] = 32'h00208463;  // beq  x1, x2, +8   → skip to addr 0x14
        t.program_hex[3] = 32'h06300193;  // addi x3, x0, 99   (SKIPPED)
        t.program_hex[4] = 32'h04D00213;  // addi x4, x0, 77   (executed)

        t.check_regs = '{1, 3, 4};
        t.exp_reg[1] = 5;
        t.exp_reg[3] = 0;   // skipped, stays 0
        t.exp_reg[4] = 77;

        t.check_mem_addrs = '{};
        t.check_mem_vals  = '{};
        tests.push_back(t);
    endfunction

    // ---------------------------------------------------------------
    //  Test 5: JAL (jump and link)
    // ---------------------------------------------------------------
    function void gen_test_jal();
        riscv_transaction t = new();
        t.test_name  = "JAL (jump and link)";
        t.run_cycles = 15;
        t.program_hex = new[5];
        t.program_hex[0] = 32'h00100093;  // addi x1, x0, 1
        t.program_hex[1] = 32'h008002EF;  // jal  x5, +8     → x5=PC+4=8, jump to 0x0C
        t.program_hex[2] = 32'h06300113;  // addi x2, x0, 99 (SKIPPED)
        t.program_hex[3] = 32'h02100193;  // addi x3, x0, 33 (landed here)
        t.program_hex[4] = 32'h00000013;  // nop

        t.check_regs = '{1, 2, 3, 5};
        t.exp_reg[1] = 1;
        t.exp_reg[2] = 0;    // skipped
        t.exp_reg[3] = 33;
        t.exp_reg[5] = 8;    // return address = PC+4 of jal instr at addr 4

        t.check_mem_addrs = '{};
        t.check_mem_vals  = '{};
        tests.push_back(t);
    endfunction

    // ---------------------------------------------------------------
    //  Test 6: LUI and AUIPC
    // ---------------------------------------------------------------
    function void gen_test_lui_auipc();
        riscv_transaction t = new();
        t.test_name  = "LUI & AUIPC";
        t.run_cycles = 10;
        t.program_hex = new[2];
        t.program_hex[0] = 32'hDEADB0B7;  // lui   x1, 0xDEADB  → x1 = 0xDEADB000
        t.program_hex[1] = 32'h00001117;  // auipc x2, 1         → x2 = PC+0x1000 = 4+0x1000 = 0x1004

        t.check_regs = '{1, 2};
        t.exp_reg[1] = 32'hDEADB000;
        t.exp_reg[2] = 32'h00001004;

        t.check_mem_addrs = '{};
        t.check_mem_vals  = '{};
        tests.push_back(t);
    endfunction

    // Generate all test cases
    function void gen_all();
        gen_test_rtype();
        gen_test_itype();
        gen_test_load_store();
        gen_test_branch();
        gen_test_jal();
        gen_test_lui_auipc();
    endfunction

endclass


// ============================================================================
//  TOP MODULE — everything lives here (driver/checker use hierarchical refs)
// ============================================================================
module tb_top;

    // ---------------------------------------------------------------
    //  Clock & Reset
    // ---------------------------------------------------------------
    logic clk, reset;
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz, period = 10 ns

    // ---------------------------------------------------------------
    //  DUT
    // ---------------------------------------------------------------
    riscv_core dut (
        .clk   (clk),
        .reset (reset)
    );

    // ---------------------------------------------------------------
    //  Backdoor access helpers (hierarchical references)
    // ---------------------------------------------------------------
    task automatic load_program(riscv_transaction t);
        int i;
        // Clear instruction memory with NOPs
        for (i = 0; i < 1024; i++)
            dut.u_instr_mem.mem[i] = 32'h00000013;
        // Clear data memory
        for (i = 0; i < 1024; i++)
            dut.u_data_mem.mem[i] = 32'h00000000;
        // Load program
        for (i = 0; i < t.program_hex.size(); i++)
            dut.u_instr_mem.mem[i] = t.program_hex[i];
    endtask

    function automatic logic [31:0] read_reg(int idx);
        if (idx == 0) return 32'b0;
        return dut.u_reg_file.registers[idx];
    endfunction

    function automatic logic [31:0] read_dmem(int word_addr);
        return dut.u_data_mem.mem[word_addr];
    endfunction

    // ---------------------------------------------------------------
    //  Driver: reset + load + run
    // ---------------------------------------------------------------
    task automatic drive(riscv_transaction t);
        // Assert reset
        reset = 1;
        @(posedge clk);
        @(posedge clk);

        // Load program into memory (backdoor)
        load_program(t);

        // Release reset
        @(posedge clk);
        reset = 0;

        // Run for N cycles
        repeat (t.run_cycles) @(posedge clk);
    endtask

    // ---------------------------------------------------------------
    //  Checker: compare actual vs expected
    // ---------------------------------------------------------------
    int total_pass, total_fail;

    task automatic check(riscv_transaction t);
        logic [31:0] actual;
        int idx;

        $display("  [CHECKER] Verifying: %s", t.test_name);

        // Check registers
        for (int i = 0; i < t.check_regs.size(); i++) begin
            idx    = t.check_regs[i];
            actual = read_reg(idx);
            if (actual !== t.exp_reg[idx]) begin
                $display("    [FAIL] x%0d = 0x%08h, expected 0x%08h",
                         idx, actual, t.exp_reg[idx]);
                total_fail++;
            end else begin
                $display("    [PASS] x%0d = 0x%08h ✓", idx, actual);
                total_pass++;
            end
        end

        // Check data memory
        for (int i = 0; i < t.check_mem_addrs.size(); i++) begin
            idx    = t.check_mem_addrs[i];
            actual = read_dmem(idx);
            if (actual !== t.check_mem_vals[i]) begin
                $display("    [FAIL] mem[%0d] = 0x%08h, expected 0x%08h",
                         idx, actual, t.check_mem_vals[i]);
                total_fail++;
            end else begin
                $display("    [PASS] mem[%0d] = 0x%08h ✓", idx, actual);
                total_pass++;
            end
        end
    endtask

    // ---------------------------------------------------------------
    //  Main test flow
    // ---------------------------------------------------------------
    riscv_generator gen;

    initial begin
        total_pass = 0;
        total_fail = 0;

        gen = new();
        gen.gen_all();

        $display("");
        $display("==========================================================");
        $display("  RISC-V Single-Cycle Core — Layered Testbench");
        $display("  Running %0d tests", gen.tests.size());
        $display("==========================================================");

        for (int i = 0; i < gen.tests.size(); i++) begin
            $display("");
            $display("----------------------------------------------------------");
            $display("  TEST %0d: %s", i+1, gen.tests[i].test_name);
            $display("----------------------------------------------------------");
            drive(gen.tests[i]);
            check(gen.tests[i]);
        end

        // Final scoreboard
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
