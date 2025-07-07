/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
(* keep_hierarchy = "yes" *)  // Prevent synthesis from flattening this module
module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire        sub,    // Operation select: 0 = add, 1 = subtract
    output reg  [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack inputs
    wire sign_a = a[31];
    wire sign_b = b[31] ^ sub;

    wire [7:0] raw_exp_a = a[30:23];
    wire [7:0] raw_exp_b = b[30:23];

    wire a_subnormal = (raw_exp_a == 8'b0);
    wire b_subnormal = (raw_exp_b == 8'b0);

    wire [7:0] exp_a = a_subnormal ? 8'd1 : raw_exp_a;
    wire [7:0] exp_b = b_subnormal ? 8'd1 : raw_exp_b;

    wire [23:0] man_a = a_subnormal ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
    wire [23:0] man_b = b_subnormal ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

    // Special values
    wire is_nan_a = (raw_exp_a == 8'hFF) && (a[22:0] != 0);
    wire is_nan_b = (raw_exp_b == 8'hFF) && (b[22:0] != 0);
    wire is_inf_a = (raw_exp_a == 8'hFF) && (a[22:0] == 0);
    wire is_inf_b = (raw_exp_b == 8'hFF) && (b[22:0] == 0);

    // Exponent alignment
    wire exp_a_greater = (exp_a >= exp_b);
    wire [7:0] exp_diff = exp_a_greater ? (exp_a - exp_b) : (exp_b - exp_a);

    wire [23:0] man_a_shifted = exp_a_greater ? man_a : (man_a >> exp_diff);
    wire [23:0] man_b_shifted = exp_a_greater ? (man_b >> exp_diff) : man_b;

    wire [7:0] exp_base = exp_a_greater ? exp_a : exp_b;

    // Aligned mantissa add/sub
    wire [24:0] extended_a = {1'b0, man_a_shifted};
    wire [24:0] extended_b = {1'b0, man_b_shifted};
    wire extended_a_greater = (extended_a >= extended_b);
    wire sign_equal = (sign_a == sign_b);

    wire [24:0] sum = sign_equal ? (extended_a + extended_b) :
                      (extended_a_greater ? extended_a - extended_b : extended_b - extended_a);
    wire sign_res = sign_equal ? sign_a : (extended_a_greater ? sign_a : sign_b);

    // Normalize result (case-based instead of for-loop)
    reg [7:0] shift;
    reg [7:0] exp_res;

    always @(*) begin
        result = 32'd0;
        shift  = 8'd0;
        exp_res = 8'd0;

        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a ^ sign_b))) begin
            result = 32'h7FC00000;  // Default quiet NaN
        end else if (is_inf_a) begin
            result = {sign_a, 8'hFF, 23'd0};  // +inf or -inf
        end else if (is_inf_b) begin
            result = {sign_b, 8'hFF, 23'd0};  // +inf or -inf
        end else if (sum == 25'd0) begin
            result = {sign_res, 31'd0};  // Signed zero
        end else if (sum[24] == 1'b1) begin
            result[31]    = sign_res;
            result[30:23] = exp_base + 1;
            result[22:0]  = sum[23:1];  // Drop LSB
        end else begin
            // Priority encoder to determine leading one position
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
                default: shift = 8'd24;
            endcase

            exp_res = exp_base - shift;

            if (exp_res == 8'd0) begin
                // Subnormal result
                result[31]    = sign_res;
                result[30:23] = 8'd0;
                result[22:0]  = sum[22:0];  // Do not shift
            end else begin
                // Normalized result
                result[31]    = sign_res;
                result[30:23] = exp_res;
                result[22:0]  = sum[22:0] << shift;
            end
        end
    end

endmodule
