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
    // Note: For 32-bit float, exponent bias is 127, so exp_a and exp_b are actually in range [-126, 127]
    //       (originally [0,255] -> (reserved) [1,254] -> (- bias) [-126,127])
    wire [7:0] exp_a;      // Biased exponent of A (don't need to account for bias in addition/subtraction since the difference between them is the same)
    wire [7:0] exp_b;      // Biased exponent of B

    // Extract mantissas and add implicit leading 1 if normalized
    // TODO: Check for exponent = all 1s (infinity or NaN) (currently does check for subnormal numbers correctly)
    wire [23:0] man_a;
    wire [23:0] man_b;
    always @(*) begin
        if (exp_a == 0) begin         // A subnormal number has biased exponenet as all 0s
            man_a = {1'b0, a[22:0]};  // Append a 0 for subnormal number (0.something)
            exp_a = a[30:23] + 1;     // Now, treat this number as if it had the smallest exponent (1 = 2^-126)
        end else begin                // A normalized number otherwise
            man_a = {1'b1, a[22:0]};  // Append a 1 for normalized number (1.something)
            exp_a = a[30:23];         // Biased exponent
        end

        if (exp_b == 0) begin
            man_b = {1'b0, b[22:0]};
            exp_b = b[30:23] + 1;
        end else begin
            man_b = {1'b1, b[22:0]};
            exp_b = b[30:23];
        end
    end

    // Step 2: Align Exponents

    // Calculate absolute exponent difference
    wire [7:0] exp_diff = (exp_a >= exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);

    // Shift the smaller mantissa to align with the larger exponent
    // Note: Should be synthesizable via barrel shifter by Verilog
    wire [23:0] man_a_shifted = (exp_a >= exp_b) ? man_a : (man_a >> exp_diff);
    wire [23:0] man_b_shifted = (exp_a >= exp_b) ? (man_b >> exp_diff) : man_b;

    // Select the greater exponent as the base for the result
    wire [7:0] exp_base = (exp_a >= exp_b) ? exp_a : exp_b;

    // Step 3: Add/Subtract Aligned Mantissas

    // Extend mantissas to 25 bits to handle overflow during addition
    wire [24:0] extended_a = {1'b0, man_a_shifted};
    wire [24:0] extended_b = {1'b0, man_b_shifted};

    wire [24:0] sum;
    wire        sign_res;

    // Perform add or subtract depending on signs
    assign {sign_res, sum} = (sign_a == sign_b) ?
                                {sign_a, extended_a + extended_b} :         // Same sign → add
                             (extended_a >= extended_b) ?                   // else, different sign means we need to check if A > B
                                {sign_a, extended_a - extended_b} :         // A > B → A - B and keep A's sign (+100 + -9 = +(100 - 9), and -100 + +9 = -(100 - 9))
                                {sign_b, extended_b - extended_a};          // B > A → B - A and keep B's sign (+9 + -100 = -(100 - 9), and -9 + +100 = +(100 - 9))

    // Step 4: Normalize Result

    wire [7:0] shift;          // Number of bits to left-shift to normalize (to put leading 1 at bit position 23)
    reg  [7:0] exp_res;        // Final biased exponent after normalization

    always @(*) begin
        if (sum[24]) begin
            // Carry bit, so result actually has a bigger exponent than base (5.2 * 10^2 + 5.3 * 10^2 = 10.5 * 10^2 = 1.05 * 10^3)
            result[31]    = sign_res;   // Sign bit
            result[30:23] = (exp_base + 1);    // Exponent (already biased)
            result[22:0]  = sum[23:1];  // Drop implicit 1 and lose the least significant bit (we lose precision as the nubmer gets bigger)
        end else begin
            // In case we have 1.432 * 10^2 - 1.431 * 10^2 = 0.001 * 10^2, we shift it to 1.000 * 10^-1
            wire [7:0] shift = 0;
            wire       found = 0;

            // Find first '1' from MSB to LSB in the sum result
            // Note: should be synthesizable combinationally since it's a fixed duration for loop, although 24 layers deep
            for (wire [7:0] i = 0; i < 24; i++) begin
                if (found)  // Skip if we've already found the first 1
                    found = 1;
                else if (sum[23 - i] & (exp_base > i)) begin
                    shift = i;  // Number of leading zeros
                    found = 1;
                end else if (sum[23 - i]) begin
                    // exp_base <= i means subnormal number (exp_base should be in range [1,254])
                    shift = exp_base;
                    found = 1;
                end else  // Use else for mux, we don't want a flip-flop / latch
                    found = 0;  // (not found, and current bit is not 1)
            end

            exp_res = exp_base - shift;  // Biased exponenet of result, should never underflow (become negative)

            // Step 5: Repack Result into IEEE Format

            if (~found)
                result = 32'd0;             // If found = 0, then sum[] is 0 (it had no 1s in it)
            else if (exp_res == 0) begin
                // Subnormal number
                result[31]    = sign_res;   // Sign bit
                result[30:23] = exp_res;    // Exponent (already biased)
                result[22:0]  = sum[22:0];  // Don't do any shifting, as the number is subnormal
            end else begin
                // Normalized number
                result[31]    = sign_res;   // Sign bit
                result[30:23] = exp_res;    // Exponent (already biased)
                result[22:0]  = (sum[22:0] << shift);  // Left shift mantissa without the first 1 by shift (is the same as shifting first and then taking the last 23 bits)
            end
        end
    end

endmodule
