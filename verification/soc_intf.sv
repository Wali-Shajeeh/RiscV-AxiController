// ============================================================================
//  RISC-V SoC — SystemVerilog Interface
// ============================================================================
//  Connects the DUT port signals to the testbench layers.
//  All testbench components access the DUT through a virtual handle to this
//  interface, ensuring clean separation between the DUT and the verification
//  environment.
// ============================================================================

interface soc_intf (input logic clk);

    // ---------------------------------------------------------------
    //  DUT Port Signals
    // ---------------------------------------------------------------
    logic        reset;
    logic        pwm_out;

endinterface
