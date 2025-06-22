/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none  // Disallow undeclared wires — forces explicit signals

module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire        sub,    // Operation select: 0 = add, 1 = subtract
    output reg  [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack Inputs

    // Extract sign bits
    wire sign_a = a[31];              // Sign of A
    wire sign_b = b[31] ^ sub;        // Sign of B (flip if subtracting)

    // Extract exponent bits
    wire [7:0] exp_a = a[30:23];      // Exponent of A
    wire [7:0] exp_b = b[30:23];      // Exponent of B

    // Extract mantissas and add implicit leading 1 if normalized
    wire [23:0] man_a = (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
    wire [23:0] man_b = (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

    // Step 2: Align Exponents

    // Calculate absolute exponent difference
    wire [7:0] exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);

    // Shift the smaller mantissa to align with the larger exponent
    wire [23:0] man_a_shifted = (exp_a >= exp_b) ? man_a : (man_a >> exp_diff);
    wire [23:0] man_b_shifted = (exp_a >= exp_b) ? (man_b >> exp_diff) : man_b;

    // Select the greater exponent as the base for the result
    wire [7:0] exp_base = (exp_a >= exp_b) ? exp_a : exp_b;

    // Align the sign bits with the shifted mantissas
    wire s_a = (exp_a >= exp_b) ? sign_a : sign_b;
    wire s_b = (exp_a >= exp_b) ? sign_b : sign_a;

    // Step 3: Add/Subtract Aligned Mantissas

    // Extend mantissas to 25 bits to handle overflow during addition
    wire [24:0] extended_a = {1'b0, man_a_shifted};
    wire [24:0] extended_b = {1'b0, man_b_shifted};

    wire [24:0] sum;
    wire        sign_res;

    // Perform add or subtract depending on aligned signs
    assign {sign_res, sum} = (s_a == s_b) ?
                             {s_a, extended_a + extended_b} :            // Same sign → add
                             (extended_a >= extended_b) ?
                                {s_a, extended_a - extended_b} :         // A > B → A - B
                                {s_b, extended_b - extended_a};          // B > A → B - A

    // Step 4: Normalize Result

    integer shift;            // Number of bits to left-shift to normalize
    reg [7:0] exp_res;        // Final exponent after normalization
    reg [23:0] norm_mant;     // Normalized mantissa

    always @(*) begin
        shift = 0;

        // Find first '1' from MSB to LSB in the sum result
        for (integer i = 24; i > 0; i = i - 1) begin
            if (sum[i]) begin
                shift = 24 - i;  // Number of leading zeros
                break;
            end
        end

        norm_mant = sum << shift;       // Normalize mantissa (shift left)
        exp_res   = exp_base - shift;   // Adjust exponent accordingly
    end

    // Step 5: Repack Result into IEEE Format

    always @(*) begin
        // Special case: result is zero
        if (sum == 0) begin
            result = 32'd0;
        end else begin
            result[31]    = sign_res;           // Sign bit
            result[30:23] = exp_res;            // Exponent (already biased)
            result[22:0]  = norm_mant[22:0];    // Mantissa (drop implicit 1)
        end
    end

endmodule
