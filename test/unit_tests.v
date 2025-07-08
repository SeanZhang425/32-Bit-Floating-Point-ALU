`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
that can be driven / tested by the cocotb test.py.
*/
module unit_tests ();

    // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
    initial begin
    $dumpfile("unit_tests.vcd");
    $dumpvars(0, unit_tests);
    #1;
    end

    // Test the whole system
    // Wire up the inputs and outputs:
    reg clk;
    reg rst_n;
    reg ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_32_bit_fp_ALU_S_M user_project (
        .ui_in   (ui_in),    // Dedicated inputs
        .uo_out  (uo_out),   // Dedicated outputs
        .uio_in  (uio_in),   // IOs: Input path
        .uio_out (uio_out),  // IOs: Output path
        .uio_oe  (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena     (ena),      // enable - goes high when design is selected
        .clk     (clk),      // clock
        .rst_n   (rst_n)     // not reset
    );


    // Test the floating point adder/subtract by itself
    wire [31:0] a;
    wire [31:0] b;
    wire sub;
    wire [31:0] result;

    fp_addsub floating_point_adder (
        .a      (a),
        .b      (b),
        .sub    (sub),
        .result (result)
    );


    // Test the state machine (alu_top) on its own
    wire [7:0] in_;
    wire [7:0] out;
    wire opcode;
    wire start;
    wire done;
    wire [3:0] state_out;

    alu_top state_machine (
        .clk       (clk),      // Clock input
        .rst_n     (rst_n),    // Active-low reset input
        .in        (in_),   // 8-bit input data bus for operand bytes
        .out       (out),   // 8-bit output data bus for result bytes
        .opcode    (opcode),  // 1-bit opcode (0 for add, 1 for subtract)
        .start     (start),  // 'Start' signal for user to request an operation
        .done      (done),  // 'Done' signal indicating ready to output data
        .state_out (state_out)// Current state of the ALU
    );

endmodule
