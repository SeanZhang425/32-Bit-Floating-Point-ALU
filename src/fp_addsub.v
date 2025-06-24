/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire        sub,    // Operation select: 0 = add, 1 = subtract
    output reg  [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack Inputs

    wire sign_a = a[31];              // Sign bit of A
    wire sign_b = b[31] ^ sub;        // Sign bit of B, flipped if we're subtracting

    // Note: For 32-bit float, exponent bias is 127, so exp_a and exp_b are actually in range [-126, 127]
    // original range: [0,255] -> without reserved values: [1,254] -> -bias: [-126,127]
    wire [7:0] raw_exp_a = a[30:23];  // Raw exponent of A
    wire [7:0] raw_exp_b = b[30:23];  // Raw exponent of B

    // TODO: Check for exponent = all 1s (infinity or NaN) (currently only checks for subnormal numbers)
    wire a_subnormal = (raw_exp_a == 8'b0);  // Is a a subnormal number?
    wire b_subnormal = (raw_exp_b == 8'b0);  // Is b a subnormal number?
    
    // Get exponent
    wire [7:0] exp_a = a_subnormal ? 8'd1 : raw_exp_a;      // Final exponent of A (adjusted if subnormal)
    wire [7:0] exp_b = b_subnormal ? 8'd1 : raw_exp_b;      // Final exponent of B

    // Get mantissa
    wire [23:0] man_a = a_subnormal ? {1'b0, a[22:0]} : {1'b1, a[22:0]};     // Mantissa of A with implicit leading 1 if normalized
    wire [23:0] man_b = b_subnormal ? {1'b0, b[22:0]} : {1'b1, b[22:0]};     // Mantissa of B with implicit leading 1 if normalized


    // Step 2: Align Exponents

    wire exp_a_greater = (exp_a >= exp_b);
    wire [7:0] exp_diff = exp_a_greater ? (exp_a - exp_b) : (exp_b - exp_a);  // Difference in exponents

    // Note: Should be synthesizable via barrel shifter by Verilog
    wire [23:0] man_a_shifted = exp_a_greater ? man_a : (man_a >> exp_diff);  // Shift A if it has smaller exponent
    wire [23:0] man_b_shifted = exp_a_greater ? (man_b >> exp_diff) : man_b;  // Shift B if it has smaller exponent

    wire [7:0] exp_base = exp_a_greater ? exp_a : exp_b;  // Base exponent after alignment


    // Step 3: Add/Subtract Aligned Mantissas

    wire [24:0] extended_a = {1'b0, man_a_shifted};   // Add leading 0 to prevent overflow and capture carry bit
    wire [24:0] extended_b = {1'b0, man_b_shifted};
    wire extended_a_greater = (extended_a >= extended_b);
    wire sign_equal = (sign_a == sign_b);

    // Add mantissa
    wire [24:0] sum = sign_equal ? extended_a + extended_b : (  // Same signs: perform addition
        extended_a_greater ? extended_a - extended_b : extended_b - extended_a  // Different signs:  A>B: do A-B, B>A: do B-A
    );
    // Final result sign (if same sign, doesn't matter. If different sign, A>B: A's sign dominates, and vice versa)
    wire        sign_res = extended_a_greater ? sign_a : sign_b;


    // Step 4: Normalize Result

    reg [7:0] shift;        // Number of left shifts needed to normalize
    reg [7:0] exp_res;      // Adjusted exponent after normalization
    reg found;              // Whether a 1 was found in sum[]
    integer i;              // Loop index for leading-1 detection

    always @(*) begin
        shift    = 8'd0;
        exp_res  = 8'd0;
        found    = 1'b0;
        
        if (sum[24] == 1'b1) begin                     // If overflow (carry-out from MSB)
            result[31]    = sign_res;                  // Assign sign
            result[30:23] = exp_base + 1;              // Exponent increments by 1 (Note: this makes the number infinity/NaN if exp_base was 254)
            result[22:0]  = sum[23:1];                 // Drop LSB and implicit 1
        end else begin
            for (i = 0; i < 24; i = i + 1) begin
                if (!found && sum[23 - i]) begin       // Find the first 1 from MSB
                    if (exp_base > i[7:0]) begin
                        shift = i[7:0];                // Shift required
                    end else begin
                        shift = exp_base;              // Subnormal case
                    end
                    found = 1'b1;
                end
            end

            exp_res = exp_base - shift;                // Normalize exponent

            if (!found) begin
                // TODO: check if there's any specifications on signed zeros here
                // it seems that it doesn't matter unless we are adding two signed zeros
                result = 32'd0;                        // If sum is zero
            end else if (exp_res == 8'd0) begin
                result[31]    = sign_res;              // Sign bit
                result[30:23] = exp_res;               // Subnormal exponent
                result[22:0]  = sum[22:0];             // Mantissa unshifted
            end else begin
                result[31]    = sign_res;              // Sign bit
                result[30:23] = exp_res;               // Normalized exponent
                result[22:0]  = (sum[22:0] << shift);  // Shifted mantissa
            end
        end
    end

endmodule
