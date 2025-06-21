/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Top-level module for the ALU project, must match the name in config.json
module tt_um_ALU (
    input  wire [7:0] ui_in,    // 8-bit dedicated input bus (operand input)
    output wire [7:0] uo_out,   // 8-bit dedicated output bus (result output)
    
    input  wire [7:0] uio_in,   // 8-bit bidirectional I/O input side (e.g., opcode, start)
    output wire [7:0] uio_out,  // 8-bit bidirectional I/O output side (e.g., done signal, debug)
    output wire [7:0] uio_oe,   // Output enable for each IO pin (1 = drive uio_out, 0 = tri-state)
    
    input  wire       ena,      // High when the project is enabled (can usually be ignored)
    input  wire       clk,      // System clock provided by Tiny Tapeout
    input  wire       rst_n     // Active-low reset signal
);
    // Internal wires to carry the bidirectional I/O signals from alu_top
    wire [7:0] alu_io_out;      // Output values to drive on IO pins
    wire [7:0] alu_io_oe;       // Output enable mask for IO pins

    // Instantiate the ALU top module with standard interface
    alu_top u_alu (
        .clk    (clk),          // Connect clock
        .rst_n  (rst_n),        // Connect active-low reset
        .in     (ui_in),        // Operand input byte from input pins
        .out    (uo_out),       // Result output byte to output pins
        .io_in  (uio_in),       // Input side of bidirectional IO (e.g., opcode, start)
        .io_out (alu_io_out),   // Output side of bidirectional IO (e.g., done, debug)
        .io_oe  (alu_io_oe)     // Output enable signals for bidirectional IO
    );

    // Drive the shared IO pins with the ALU's outputs and enables
    assign uio_out = alu_io_out;    // Pass through output data from alu_top
    assign uio_oe  = alu_io_oe;     // Pass through output enable mask from alu_top
    
    // List all unused inputs to prevent warnings
    wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
