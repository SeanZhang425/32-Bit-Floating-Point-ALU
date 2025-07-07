/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Prevent synthesis tools from flattening this module to reduce synthesis memory usage
(* keep_hierarchy = "yes" *)
module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire        sub,    // Operation select: 0 = add, 1 = subtract
    output reg  [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack inputs

    wire sign_a = a[31];             // Sign bit of A
    wire sign_b = b[31] ^ sub;       // Sign bit of B, flipped if subtracting

    wire [7:0] raw_exp_a = a[30:23]; // Raw exponent of A
    wire [7:0] raw_exp_b = b[30:23]; // Raw exponent of B

    wire a_subnormal = (raw_exp_a == 8'b0); // Check if A is subnormal
    wire b_subnormal = (raw_exp_b == 8'b0); // Check if B is subnormal

    wire [7:0] exp_a = a_subnormal ? 8'd1 : raw_exp_a; // Adjust exponent of A for subnormal
    wire [7:0] exp_b = b_subnormal ? 8'd1 : raw_exp_b; // Adjust exponent of B for subnormal

    wire [23:0] man_a = a_subnormal ? {1'b0, a[22:0]} : {1'b1, a[22:0]}; // Mantissa of A with implicit leading 1 if normalized
    wire [23:0] man_b = b_subnormal ? {1'b0, b[22:0]} : {1'b1, b[22:0]}; // Mantissa of B with implicit leading 1 if normalized

    // Step 1.5: Handle special cases (NaN and infinity)

    wire is_nan_a = (raw_exp_a == 8'hFF) && (a[22:0] != 0);  // A is NaN if exponent is all 1s and mantissa is nonzero
    wire is_nan_b = (raw_exp_b == 8'hFF) && (b[22:0] != 0);  // B is NaN

    wire is_inf_a = (raw_exp_a == 8'hFF) && (a[22:0] == 0);  // A is infinity
    wire is_inf_b = (raw_exp_b == 8'hFF) && (b[22:0] == 0);  // B is infinity

    // Step 2: Align exponents

    wire exp_a_greater = (exp_a >= exp_b); // Determine which operand has greater exponent
    wire [7:0] exp_diff = exp_a_greater ? (exp_a - exp_b) : (exp_b - exp_a); // Compute exponent difference

    wire [23:0] man_a_shifted = exp_a_greater ? man_a : (man_a >> exp_diff); // Shift A's mantissa if needed
    wire [23:0] man_b_shifted = exp_a_greater ? (man_b >> exp_diff) : man_b; // Shift B's mantissa if needed

    wire [7:0] exp_base = exp_a_greater ? exp_a : exp_b; // Base exponent used after alignment

    // Step 3: Add/Sub aligned mantissas

    wire [24:0] extended_a = {1'b0, man_a_shifted}; // Extend mantissas to 25 bits (guard bit)
    wire [24:0] extended_b = {1'b0, man_b_shifted};

    wire extended_a_greater = (extended_a >= extended_b); // Determine dominant magnitude
    wire sign_equal = (sign_a == sign_b);                 // True if signs are the same

    wire [24:0] sum = sign_equal ? (extended_a + extended_b) : // If same sign: add
                      (extended_a_greater ? extended_a - extended_b : extended_b - extended_a); // Else: subtract smaller from larger

    wire sign_res = sign_equal ? sign_a : (extended_a_greater ? sign_a : sign_b); // Determine result sign based on dominant operand

    // Step 4: Normalize result using static priority encoder (no for-loop)

    reg [7:0] shift;     // Number of left shifts required for normalization
    reg [7:0] exp_res;   // Final adjusted exponent

    always @(*) begin
        // Default result to 0
        result = 32'd0;
        shift = 8'd0;
        exp_res = 8'd0;

        // Special case: NaN or inf - inf
        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a ^ sign_b))) begin
            result = 32'h7FC00000; // Return quiet NaN
        end
        // Special case: A is infinity
        else if (is_inf_a) begin
            result = {sign_a, 8'hFF, 23'd0}; // Return signed infinity
        end
        // Special case: B is infinity
        else if (is_inf_b) begin
            result = {sign_b, 8'hFF, 23'd0}; // Return signed infinity
        end
        // Special case: result is exactly zero (e.g. a - a)
        else if (sum == 25'd0) begin
            result = {sign_res, 31'd0}; // Signed zero
        end
        // If MSB is 1 (overflow), shift right and increment exponent
        else if (sum[24] == 1'b1) begin
            result[31]    = sign_res;           // Sign bit
            result[30:23] = exp_base + 1;       // Increase exponent
            result[22:0]  = sum[23:1];          // Drop LSB and leading 1
        end
        // Else normalize using priority encoder
        else begin
            // Priority encoder to detect how much to left-shift the mantissa
            casez (sum[23:0])
                24'b1???????????????????????: shift = 0;
                24'b01??????????????????????: shift = 1;
                24'b001?????????????????????: shift = 2;
                24'b0001????????????????????: shift = 3;
                24'b00001???????????????????: shift = 4;
                24'b000001??????????????????: shift = 5;
                24'b0000001?????????????????: shift = 6;
                24'b00000001????????????????: shift = 7;
                24'b000000001???????????????: shift = 8;
                24'b0000000001??????????????: shift = 9;
                24'b00000000001?????????????: shift = 10;
                24'b000000000001????????????: shift = 11;
                24'b0000000000001???????????: shift = 12;
                24'b00000000000001??????????: shift = 13;
                24'b000000000000001?????????: shift = 14;
                24'b0000000000000001????????: shift = 15;
                24'b00000000000000001???????: shift = 16;
                24'b000000000000000001??????: shift = 17;
                24'b0000000000000000001?????: shift = 18;
                24'b00000000000000000001????: shift = 19;
                24'b000000000000000000001???: shift = 20;
                24'b0000000000000000000001??: shift = 21;
                24'b00000000000000000000001?: shift = 22;
                24'b000000000000000000000001: shift = 23;
                default: shift = 8'd24; // Should never happen
            endcase

            exp_res = exp_base - shift; // Adjust exponent

            // Subnormal result (exponent underflows)
            if (exp_res == 8'd0) begin
                result[31]    = sign_res;       // Sign bit
                result[30:23] = 8'd0;           // Exponent = 0
                result[22:0]  = sum[22:0];      // Unshifted mantissa
            end
            // Normalized result
            else begin
                result[31]    = sign_res;             // Sign bit
                result[30:23] = exp_res;              // Adjusted exponent
                result[22:0]  = sum[22:0] << shift;   // Left-shifted mantissa
            end
        end
    end

endmodule
