/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Prevent hierarchy flattening in synthesis to reduce fanout/resource issues
(* keep_hierarchy = "yes" *)
module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire        sub,    // Operation select: 0 = add, 1 = subtract
    output reg  [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack Inputs
    wire sign_a = a[31];               // Sign bit of A
    wire sign_b = b[31] ^ sub;         // Sign bit of B, flipped if subtracting

    wire [7:0] raw_exp_a = a[30:23];   // Raw exponent of A
    wire [7:0] raw_exp_b = b[30:23];   // Raw exponent of B

    wire a_subnormal = (raw_exp_a == 8'b0);  // Is A a subnormal number?
    wire b_subnormal = (raw_exp_b == 8'b0);  // Is B a subnormal number?

    wire [7:0] exp_a = a_subnormal ? 8'd1 : raw_exp_a; // Exponent of A (adjusted for subnormal)
    wire [7:0] exp_b = b_subnormal ? 8'd1 : raw_exp_b; // Exponent of B (adjusted for subnormal)

    wire [23:0] man_a = a_subnormal ? {1'b0, a[22:0]} : {1'b1, a[22:0]}; // Mantissa of A with implicit leading 1 if normalized
    wire [23:0] man_b = b_subnormal ? {1'b0, b[22:0]} : {1'b1, b[22:0]}; // Mantissa of B with implicit leading 1 if normalized

    // Step 1.5: Special Value Detection
    wire is_nan_a = (raw_exp_a == 8'hFF) && (a[22:0] != 0);   // A is NaN
    wire is_nan_b = (raw_exp_b == 8'hFF) && (b[22:0] != 0);   // B is NaN

    wire is_inf_a = (raw_exp_a == 8'hFF) && (a[22:0] == 0);   // A is infinity
    wire is_inf_b = (raw_exp_b == 8'hFF) && (b[22:0] == 0);   // B is infinity

    // Step 2: Align Exponents
    wire exp_a_greater = (exp_a >= exp_b);                         // Determine which operand has larger exponent
    wire [7:0] exp_diff = exp_a_greater ? (exp_a - exp_b) : (exp_b - exp_a); // Compute exponent difference

    wire [23:0] man_a_shifted = exp_a_greater ? man_a : (man_a >> exp_diff); // Shift A if it has smaller exponent
    wire [23:0] man_b_shifted = exp_a_greater ? (man_b >> exp_diff) : man_b; // Shift B if it has smaller exponent

    wire [7:0] exp_base = exp_a_greater ? exp_a : exp_b;           // Base exponent after alignment

    // Step 3: Mantissa Add/Sub
    wire [24:0] extended_a = {1'b0, man_a_shifted};                // Extend A to 25 bits to handle overflow/carry
    wire [24:0] extended_b = {1'b0, man_b_shifted};                // Extend B similarly
    wire extended_a_greater = (extended_a >= extended_b);         // Compare magnitudes to determine dominant operand
    wire sign_equal = (sign_a == sign_b);                         // True if adding same-signed values

    // Perform addition or subtraction based on signs
    wire [24:0] sum = sign_equal ? (extended_a + extended_b) :
                      (extended_a_greater ? extended_a - extended_b : extended_b - extended_a);

    wire sign_res = sign_equal ? sign_a : (extended_a_greater ? sign_a : sign_b); // Determine result sign

    // Step 4: Normalize result
    reg [7:0] shift;      // Number of bits to left-shift mantissa
    reg [7:0] exp_res;    // Final exponent after normalization
    reg found;            // Flag to indicate first '1' found in normalization
    integer i;            // Loop variable for leading-one detection

    always @(*) begin
        shift    = 8'd0;
        exp_res  = 8'd0;
        found    = 1'b0;
        result   = 32'd0;               // Default result to zero

        // Handle special values first
        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a ^ sign_b))) begin
            result = 32'h7FC00000;      // Return default quiet NaN if NaN present or inf - inf
        end else if (is_inf_a) begin
            result = {sign_a, 8'hFF, 23'd0}; // A is infinity, return with correct sign
        end else if (is_inf_b) begin
            result = {sign_b, 8'hFF, 23'd0}; // B is infinity, return with correct sign (may be flipped)
        end else begin
            // No special values, proceed with normal computation

            if (sum[24]) begin                      // If MSB is 1 (carry out), shift right
                result[31]    = sign_res;           // Assign sign
                result[30:23] = exp_base + 1;       // Increase exponent due to normalization shift
                result[22:0]  = sum[23:1];          // Drop LSB, store remaining mantissa
            end else begin
                // Need to normalize by left-shifting mantissa
                for (i = 0; i < 24; i = i + 1) begin
                    if (!found && sum[23 - i]) begin
                        shift = (exp_base > i[7:0]) ? i[7:0] : exp_base; // WIDTHEXPAND fix: force i to 8 bits
                        found = 1'b1;
                    end
                end

                exp_res = exp_base - shift;         // Compute adjusted exponent

                if (!found) begin
                    result = {sign_res, 31'd0};     // Result is zero
                end else if (exp_res == 8'd0) begin
                    result[31]    = sign_res;       // Sign bit
                    result[30:23] = 8'd0;           // Subnormal exponent
                    result[22:0]  = sum[22:0];      // Leave mantissa unshifted
                end else begin
                    result[31]    = sign_res;           // Sign bit
                    result[30:23] = exp_res;            // Adjusted exponent
                    result[22:0]  = sum[22:0] << shift; // Normalized mantissa
                end
            end
        end
    end

endmodule
