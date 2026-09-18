// =============================================================
// tb_riscv_core_mc.sv — Self-Checking Testbench for Multicycle RV32I
// =============================================================
`timescale 1ns / 1ps

module tb_riscv_core_mc;

    logic clk, reset;
    integer pass_count, fail_count;

    // ---- DUT ----
    riscv_core_mc dut (
        .clk   (clk),
        .reset (reset)
    );

    // ---- Clock: 10ns period (100 MHz) ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Helper task: wait N clock cycles ----
    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    // ---- Helper task: check register value ----
    task automatic check_reg(input int reg_num, input logic [31:0] expected, input string name);
        logic [31:0] actual;
        actual = dut.u_reg_file.registers[reg_num];
        if (actual === expected) begin
            $display("[PASS] %s: x%0d = 0x%08h (expected 0x%08h)", name, reg_num, actual, expected);
            pass_count++;
        end else begin
            $display("[FAIL] %s: x%0d = 0x%08h (expected 0x%08h)", name, reg_num, actual, expected);
            fail_count++;
        end
    endtask

    // ---- Helper task: check memory value ----
    task automatic check_mem(input int word_addr, input logic [31:0] expected, input string name);
        logic [31:0] actual;
        actual = dut.u_data_mem.mem[word_addr];
        if (actual === expected) begin
            $display("[PASS] %s: mem[%0d] = 0x%08h", name, word_addr, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s: mem[%0d] = 0x%08h (expected 0x%08h)", name, word_addr, actual, expected);
            fail_count++;
        end
    endtask

    // ---- Main test ----
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("==============================================");
        $display("  Multicycle RV32I Core — Simulation Start");
        $display("==============================================");

        // ---- Reset ----
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        $display("\n[INFO] Reset released at time %0t ns", $time);

        // ============================================
        // Wait for all instructions to complete
        // Each instruction takes 3-5 cycles:
        //   - ADDI/R-type/LUI/AUIPC: 4 cycles
        //   - LW: 5 cycles
        //   - SW/Store: 4 cycles
        //   - Branch/JAL: 3 cycles
        //   - SKIPPED instrs: 0 cycles
        //
        // Total instructions executed: ~22 (2 skipped)
        // Worst case: 22 * 5 = 110 cycles, let's wait 150
        // ============================================
        wait_cycles(150);

        $display("\n---------- Register Check ----------");

        // Instruction results:
        // addi x1, x0, 5       → x1 = 5
        check_reg(1,  32'd5,         "ADDI x1=5");

        // addi x2, x0, 10      → x2 = 10
        check_reg(2,  32'd10,        "ADDI x2=10");

        // add x3, x1, x2       → x3 = 15
        check_reg(3,  32'd15,        "ADD x3=x1+x2");

        // sub x4, x2, x1       → x4 = 5
        check_reg(4,  32'd5,         "SUB x4=x2-x1");

        // and x5, x1, x2       → x5 = 5 & 10 = 0
        check_reg(5,  32'd0,         "AND x5=x1&x2");

        // or x6, x1, x2        → x6 = 5 | 10 = 15
        check_reg(6,  32'd15,        "OR x6=x1|x2");

        // xor x7, x1, x2       → x7 = 5 ^ 10 = 15
        check_reg(7,  32'd15,        "XOR x7=x1^x2");

        // slt x8, x1, x2       → x8 = (5 < 10) = 1
        check_reg(8,  32'd1,         "SLT x8=(x1<x2)");

        // addi x9, x0, 100     → x9 = 100
        check_reg(9,  32'd100,       "ADDI x9=100");

        // lw x10, 0(x9)        → x10 = mem[100] = 15
        check_reg(10, 32'd15,        "LW x10=mem[100]");

        // addi x11, x0, -1     → x11 = 0xFFFFFFFF
        check_reg(11, 32'hFFFFFFFF,  "ADDI x11=-1");

        // lb x12, 4(x9)        → x12 = sign_ext(0xFF) = -1
        check_reg(12, 32'hFFFFFFFF,  "LB x12=sext(0xFF)");

        // lbu x13, 4(x9)       → x13 = zero_ext(0xFF) = 255
        check_reg(13, 32'd255,       "LBU x13=zext(0xFF)");

        // lui x14, 0x12345     → x14 = 0x12345000
        check_reg(14, 32'h12345000,  "LUI x14=0x12345000");

        // auipc x15, 0x00001   → x15 = PC(0x40) + 0x1000 = 0x1040
        check_reg(15, 32'h00001040,  "AUIPC x15=PC+0x1000");

        // beq x1, x4 → taken (x1=5, x4=5), skip x16=99
        // x16 should remain 0
        check_reg(16, 32'd0,         "BEQ skip: x16 not written");

        // addi x17, x0, 42     → x17 = 42
        check_reg(17, 32'd42,        "ADDI x17=42 (after branch)");

        // jal x18, done        → x18 = PC(0x50) + 4 = 0x54
        check_reg(18, 32'h00000054,  "JAL x18=return_addr");

        // x19 should be skipped (JAL jumps over it)
        check_reg(19, 32'd0,         "JAL skip: x19 not written");

        // addi x20, x0, 1      → x20 = 1 (DONE marker)
        check_reg(20, 32'd1,         "ADDI x20=1 (DONE)");

        // x0 should always be 0
        check_reg(0,  32'd0,         "x0 hardwired zero");

        $display("\n---------- Memory Check ----------");

        // sw x3, 0(x9)         → mem[word_addr=25] = 15    (byte addr 100, word addr 100/4=25)
        check_mem(25, 32'd15,        "SW mem[100]=15");

        $display("\n---------- FSM State Check ----------");
        $display("[INFO] Final PC = 0x%08h", dut.pc_current);
        $display("[INFO] Final FSM state = %0d", dut.u_controller.state);

        $display("\n==============================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==============================================");

        if (fail_count == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");

        $display("");
        $finish;
    end

    // ---- Waveform dump for debugging ----
    initial begin
        $dumpfile("riscv_mc_wave.vcd");
        $dumpvars(0, tb_riscv_core_mc);
    end

    // ---- Timeout safety ----
    initial begin
        #20000;
        $display("[TIMEOUT] Simulation exceeded 20us — stopping");
        $finish;
    end

endmodule
