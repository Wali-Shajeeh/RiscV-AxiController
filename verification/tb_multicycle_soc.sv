`timescale 1ns / 1ps

module tb_riscv_soc_mc;

    logic clk;
    logic reset;
    logic pwm_out;

    riscv_soc_mc dut (
        .clk     (clk),
        .reset   (reset),
        .pwm_out (pwm_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("==============================================");
        $display("  Multicycle AXI SoC — PWM Peripheral Test");
        $display("==============================================");

        reset = 1;
        #20 reset = 0;
        
        $display("[INFO] Simulation started, waiting for CPU to configure PWM...");

        // CPU takes a few cycles per instruction.
        // Wait long enough for configuration to complete (approx 50-100 cycles)
        #1000;
        
        $display("[INFO] PWM should be active now. Monitoring pwm_out...");

        // Wait for pwm_out to go high
        @(posedge pwm_out);
        $display("[PASS] %0t: pwm_out went HIGH", $time);

        // Wait for pwm_out to go low
        @(negedge pwm_out);
        $display("[PASS] %0t: pwm_out went LOW", $time);
        
        // Wait for next high to measure period
        @(posedge pwm_out);
        $display("[PASS] %0t: pwm_out went HIGH (1 period complete)", $time);

        #100;
        $display("==============================================");
        $display("  >>> TEST PASSED <<<");
        $display("==============================================");
        $finish;
    end

        // Timeout
    initial begin
        #5000;
        $display("[FAIL] Timeout: PWM never started toggling.");
        $finish;
    end

    always @(posedge clk) begin
        if (dut.mem_write) begin
            $display("Time=%0t | PC=%h | WRITE ADDR=%h DATA=%h is_periph=%b mem_ready=%b", 
                     $time, dut.pc_current, dut.ALUOut, dut.B, dut.is_peripheral_access, dut.mem_ready);
        end
        if (dut.u_axi_adapter.state != 0) begin
            $display("Time=%0t | AXI Adapter State=%0d", $time, dut.u_axi_adapter.state);
        end
    end
endmodule
