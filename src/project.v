/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Top-level module for the ALU project, must match the name in info.yaml
module tt_um_32_bit_fp_ALU_S_M (
    input  wire [7:0] ui_in,    // 8-bit dedicated input bus (operand input)
    output wire [7:0] uo_out,   // 8-bit dedicated output bus (result output)
    
    input  wire [7:0] uio_in,   // 8-bit bidirectional I/O input side (e.g., opcode, start)
    output wire [7:0] uio_out,  // 8-bit bidirectional I/O output side (e.g., done signal, debug)
    output wire [7:0] uio_oe,   // Output enable for each IO pin (1 = drive uio_out, 0 = tri-state)
    
    input  wire       ena,      // High when the project is enabled (can usually be ignored)
    input  wire       clk,      // System clock provided by Tiny Tapeout
    input  wire       rst_n     // Active-low reset signal
);
    // Set the direction for shared IO pins (it is static, direction never changes)
    assign uio_oe = 8'b1111_1000;   // io[7:4] outputs state, io[3] is the 'done' signal.

    // Instantiate the ALU top module with standard interface
    alu_top u_alu (
        .clk       (clk),           // Connect clock
        .rst_n     (rst_n),         // Connect active-low reset
        .in        (ui_in),         // Operand input byte from input pins
        .out       (uo_out),        // Result output byte to output pins
        .opcode    (uio_in[0]),     // Opcode: choose which operation for ALU to do
        .start     (uio_in[2]),     // 'Start' signal: request ALU to do an operation
        .done      (uio_out[3]),    // 'Done' signal: ready for outputting
        .state_out (uio_out[7:4])   // Current state of ALU
    );

    assign uio_out[2:0] = 3'b000;  // Avoid "undriven" warning

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in[7:3], uio_in[1], 1'b0};

endmodule
