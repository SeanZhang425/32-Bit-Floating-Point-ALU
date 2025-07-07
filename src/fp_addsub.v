/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Prevent OpenLane from flattening this module to reduce memory usage
(* keep_hierarchy = "yes" *)
module fp_addsub (
    input  wire [31:0] a,       // Input float A (IEEE 754 format)
    input  wire [31:0] b,       // Input float B (IEEE 754 format)
    input  wire        sub,     // Operation: 0 = add, 1 = subtract
    output reg  [31:0] result   // IEEE 754 result
);

    // Step 1: Unpack inputs
    wire sign_a = a[31];              // Sign of A
    wire sign_b = b[31] ^ sub;        // Sign of B (flip if subtracting)

    wire [7:0] raw_exp_a = a[30:23];  // Raw exponent of A
    wire [7:0] raw_exp_b = b[30:23];  // Raw exponent of B

    wire a_subnormal = (raw_exp_a == 8'b0);   // Detect if A is subnormal
    wire b_subnormal = (raw_exp_b == 8'b0);   // Detect if B is subnormal

    wire [7:0] exp_a = a_subnormal ? 8'd1 : raw_exp_a;  // Use 1 instead of 0 for subnormals
    wire [7:0] exp_b = b_subnormal ? 8'd1 : raw_exp_b;

    wire [23:0] man_a = a_subnormal ? {1'b0, a[22:0]} : {1'b1, a[22:0]}; // Add implicit leading 1 if normalized
    wire [23:0] man_b = b_subnormal ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

    // Step 1.5: Special value detection
    wire is_nan_a = (raw_exp_a == 8'hFF) && (a[22:0] != 0);   // A is NaN
    wire is_nan_b = (raw_exp_b == 8'hFF) && (b[22:0] != 0);   // B is NaN

    wire is_inf_a = (raw_exp_a == 8'hFF) && (a[22:0] == 0);   // A is infinity
    wire is_inf_b = (raw_exp_b == 8'hFF) && (b[22:0] == 0);   // B is infinity

    // Step 2: Exponent alignment
    wire exp_a_greater = (exp_a >= exp_b);                           // Compare exponents
    wire [7:0] exp_diff = exp_a_greater ? (exp_a - exp_b) : (exp_b - exp_a); // Difference

    wire [23:0] man_a_shifted = exp_a_greater ? man_a : (man_a >> exp_diff); // Shift smaller
    wire [23:0] man_b_shifted = exp_a_greater ? (man_b >> exp_diff) : man_b;

    wire [7:0] exp_base = exp_a_greater ? exp_a : exp_b;             // Exponent to use after alignment

    // Step 3: Add/Subtract mantissas
    wire [24:0] extended_a = {1'b0, man_a_shifted};   // Add leading 0 to avoid overflow
    wire [24:0] extended_b = {1'b0, man_b_shifted};

    wire extended_a_greater = (extended_a >= extended_b);            // Used for sign of result
    wire sign_equal = (sign_a == sign_b);                            // True if both operands same sign

    wire [24:0] sum = sign_equal ?
                      (extended_a + extended_b) :                    // Add if signs match
                      (extended_a_greater ? extended_a - extended_b // Subtract larger - smaller
                                           : extended_b - extended_a);

    wire sign_res = sign_equal ? sign_a : (extended_a_greater ? sign_a : sign_b); // Result sign logic

    // Step 4: Normalize result
    reg [4:0] shift_amt;  // How much to left-shift the mantissa
    always @(*) begin
        casez (sum[23:0]) // Priority encoder using casez to detect leading 1
            24'b1???????????????????????: shift_amt = 0;
            24'b01??????????????????????: shift_amt = 1;
            24'b001?????????????????????: shift_amt = 2;
            24'b0001????????????????????: shift_amt = 3;
            24'b00001???????????????????: shift_amt = 4;
            24'b000001??????????????????: shift_amt = 5;
            24'b0000001?????????????????: shift_amt = 6;
            24'b00000001????????????????: shift_amt = 7;
            24'b000000001???????????????: shift_amt = 8;
            24'b0000000001??????????????: shift_amt = 9;
            24'b00000000001?????????????: shift_amt = 10;
            24'b000000000001????????????: shift_amt = 11;
            24'b0000000000001???????????: shift_amt = 12;
            24'b00000000000001??????????: shift_amt = 13;
            24'b000000000000001?????????: shift_amt = 14;
            24'b0000000000000001????????: shift_amt = 15;
            24'b00000000000000001???????: shift_amt = 16;
            24'b000000000000000001??????: shift_amt = 17;
            24'b0000000000000000001?????: shift_amt = 18;
            24'b00000000000000000001????: shift_amt = 19;
            24'b000000000000000000001???: shift_amt = 20;
            24'b0000000000000000000001??: shift_amt = 21;
            24'b00000000000000000000001?: shift_amt = 22;
            24'b000000000000000000000001: shift_amt = 23;
            default: shift_amt = 24; // Shouldn't happen (sum is all zero)
        endcase
    end

    // Final exponent computation and result assembly
    reg [7:0] exp_res;
    always @(*) begin
        result = 32'd0;  // Default result

        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a ^ sign_b))) begin
            result = 32'h7FC00000;  // Quiet NaN for invalid cases
        end else if (is_inf_a) begin
            result = {sign_a, 8'hFF, 23'd0}; // A is infinity
        end else if (is_inf_b) begin
            result = {sign_b, 8'hFF, 23'd0}; // B is infinity
        end else if (sum[24]) begin
            result[31]    = sign_res;       // Carry out → overflow normalization
            result[30:23] = exp_base + 1;
            result[22:0]  = sum[23:1];      // Drop LSB
        end else if (sum[23:0] == 24'd0) begin
            result = {sign_res, 31'd0};     // Result is exactly zero
        end else begin
            exp_res = exp_base - shift_amt; // Normalization step

            if (exp_res == 8'd0) begin
                result[31]    = sign_res;       // Subnormal case
                result[30:23] = 8'd0;
                result[22:0]  = sum[22:0];      // No shift
            end else begin
                result[31]    = sign_res;       // Normalized result
                result[30:23] = exp_res;
                result[22:0]  = sum[22:0] << shift_amt;
            end
        end
    end

endmodule
