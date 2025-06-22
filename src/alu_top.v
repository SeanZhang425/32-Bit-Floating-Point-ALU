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

    input  wire [7:0] io_in,     // 8-bit bidirectional I/O input bus (opcode and start)
    output reg  [7:0] io_out,    // 8-bit bidirectional I/O output bus (done signal)
    output reg  [7:0] io_oe      // Output enable signals for each IO bit
);

    // Extract control signals from input I/O pins
    wire [2:0] opcode = io_in[2:0];  // Opcode: 000 for add, 001 for subtract
    wire       start  = io_in[3];    // Start signal to begin reading input

    // Define the finite state machine (FSM) states
    typedef enum logic [3:0] {
        IDLE        = 4'd0,   // Waiting for start signal
        LOAD_A_0    = 4'd1,   // Load byte 0 of operand A
        LOAD_A_1    = 4'd2,   // Load byte 1 of operand A
        LOAD_A_2    = 4'd3,   // Load byte 2 of operand A
        LOAD_A_3    = 4'd4,   // Load byte 3 of operand A
        LOAD_B_0    = 4'd5,   // Load byte 0 of operand B
        LOAD_B_1    = 4'd6,   // Load byte 1 of operand B
        LOAD_B_2    = 4'd7,   // Load byte 2 of operand B
        LOAD_B_3    = 4'd8,   // Load byte 3 of operand B
        EXECUTE     = 4'd9,   // Perform the operation
        OUTPUT_0    = 4'd10,  // Output byte 0 of result
        OUTPUT_1    = 4'd11,  // Output byte 1 of result
        OUTPUT_2    = 4'd12,  // Output byte 2 of result
        OUTPUT_3    = 4'd13   // Output byte 3 of result
    } state_t;

    state_t state;  // Holds the current state

    // Registers to store input operands and computation result
    reg [31:0] operand_a;   // First input operand
    reg [31:0] operand_b;   // Second input operand
    reg [31:0] result;      // Final result after computation

    // Decide if operation is subtraction based on opcode
    wire sub = (opcode == 3'b001);  // 1 if subtract, 0 if add

    // Wire to receive the result from the floating-point adder/subtractor
    wire [31:0] addsub_result;

    // Instantiate the floating-point add/subtract unit
    fp_addsub u_addsub (
        .a      (operand_a),       // First operand input
        .b      (operand_b),       // Second operand input
        .sub    (sub),             // Control: 1 for subtract, 0 for add
        .result (addsub_result)    // Output result
    );

    // Sequential logic: handles state transitions, input loading, and output
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers and return to IDLE
            state      <= IDLE;
            operand_a  <= 32'd0;
            operand_b  <= 32'd0;
            result     <= 32'd0;
            out        <= 8'd0;
            io_out     <= 8'd0;
            io_oe      <= 8'd0;
        end else begin
            // FSM: handle each phase of the ALU operation
            case (state)
                IDLE: begin
                    if (start)           // Wait for start signal
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
                    result <= addsub_result;   // Capture result
                    state  <= OUTPUT_0;        // Begin output phase
                end

                // Output result byte-by-byte, LSB to MSB
                OUTPUT_0: begin
                    out        <= result[7:0];   // Send byte 0
                    state      <= OUTPUT_1;
                    io_out[4]  <= 1'b1;          // Set 'done' high
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
                    io_out[4]  <= 1'b0;          // Clear 'done'
                end
            endcase
        end
    end

    // Combinational logic to drive output enable pins
    always_comb begin
        io_oe = 8'b00000000;  // Default: disable all outputs
        io_oe[4] = 1'b1;      // Enable only the 'done' signal output
        // Add more enables here if you want to expose debug signals
    end

endmodule


