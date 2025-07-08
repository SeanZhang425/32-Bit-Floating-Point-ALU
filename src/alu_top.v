/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu_top (
    input  wire       clk,       // Clock input
    input  wire       rst_n,     // Active-low reset input
    input  wire [7:0] in,        // 8-bit input data bus for operand bytes
    output reg  [7:0] out,       // 8-bit output data bus for result bytes

    input  wire       opcode,    // 1-bit opcode (0 for add, 1 for subtract)
    input  wire       start,     // 'Start' signal for user to request an operation
    output reg        done,      // 'Done' signal indicating ready to output data
    output wire [3:0] state_out  // Current state of the ALU
);
    // Define the finite state machine (FSM) states
    parameter IDLE        = 4'd0;   // Waiting for start signal
    parameter LOAD_A_0    = 4'd1;   // Load byte 0 of operand A
    parameter LOAD_A_1    = 4'd2;   // Load byte 1 of operand A
    parameter LOAD_A_2    = 4'd3;   // Load byte 2 of operand A
    parameter LOAD_A_3    = 4'd4;   // Load byte 3 of operand A
    parameter LOAD_B_0    = 4'd5;   // Load byte 0 of operand B
    parameter LOAD_B_1    = 4'd6;   // Load byte 1 of operand B
    parameter LOAD_B_2    = 4'd7;   // Load byte 2 of operand B
    parameter LOAD_B_3    = 4'd8;   // Load byte 3 of operand B
    parameter EXECUTE     = 4'd9;   // Perform the operation
    parameter OUTPUT_0    = 4'd10;  // Output byte 0 of result
    parameter OUTPUT_1    = 4'd11;  // Output byte 1 of result
    parameter OUTPUT_2    = 4'd12;  // Output byte 2 of result
    parameter OUTPUT_3    = 4'd13;   // Output byte 3 of result

    // Register declaration
    reg [3:0]  state;       // Current state of ALU
    reg [31:0] operand_a;   // First input operand
    reg [31:0] operand_b;   // Second input operand
    reg [31:0] result;      // Final result after computation

    // Decide if operation is subtraction based on opcode
    wire sub = opcode;  // 1 if subtract, 0 if add

    // Wire to receive the result from the floating-point adder/subtractor
    wire [31:0] addsub_result;

    // Connect state register to the output for debug
    assign state_out = state;

    // Instantiate the floating-point add/subtract unit
    fp_addsub u_addsub (
        .a      (operand_a),       // First operand input
        .b      (operand_b),       // Second operand input
        .sub    (sub),             // Control: 1 for subtract, 0 for add
        .result (addsub_result)    // Output result
    );

    // Sequential logic: handles state transitions, input loading, and output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers and return to IDLE
            state      <= IDLE;
            operand_a  <= 32'd0;
            operand_b  <= 32'd0;
            result     <= 32'd0;
            out        <= 8'd0;
            done       <= 1'b0;
        end else begin
            // FSM: handle each phase of the ALU operation
            case (state)
                IDLE: begin
                    done <= 1'b0;  // Reset done signal
                    if (start)     // Wait for start signal
                        state <= LOAD_A_0;
                end

                // Load 32-bit operand A one byte per cycle (LSB to MSB)
                LOAD_A_0: begin operand_a[7:0]    <= in; state <= LOAD_A_1; end
                LOAD_A_1: begin operand_a[15:8]   <= in; state <= LOAD_A_2; end
                LOAD_A_2: begin operand_a[23:16]  <= in; state <= LOAD_A_3; end
                LOAD_A_3: begin operand_a[31:24]  <= in; state <= LOAD_B_0; end

                // Load 32-bit operand B one byte per cycle (LSB to MSB)
                LOAD_B_0: begin operand_b[7:0]    <= in; state <= LOAD_B_1; end
                LOAD_B_1: begin operand_b[15:8]   <= in; state <= LOAD_B_2; end
                LOAD_B_2: begin operand_b[23:16]  <= in; state <= LOAD_B_3; end
                LOAD_B_3: begin operand_b[31:24]  <= in; state <= EXECUTE; end

                // Perform the selected floating-point operation
                EXECUTE: begin
                    result <= addsub_result;   // Capture result TODO: We will need to make sure that fp_addsub finishes within 1 clock cycle
                    state  <= OUTPUT_0;        // Begin output phase
                end

                // Output result byte-by-byte, LSB to MSB
                OUTPUT_0: begin
                    out        <= result[7:0];   // Send byte 0
                    state      <= OUTPUT_1;
                    done       <= 1'b1;          // Set 'done' high
                end
                OUTPUT_1: begin
                    out        <= result[15:8];  // Send byte 1
                    state      <= OUTPUT_2;
                end
                OUTPUT_2: begin
                    out        <= result[23:16]; // Send byte 2
                    state      <= OUTPUT_3;
                end
                OUTPUT_3: begin
                    out        <= result[31:24]; // Send byte 3
                    state      <= IDLE;          // Go back to IDLE
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


