/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
module fp_addsub (
    input  wire [31:0] a,      // Input float A (IEEE 754 format)
    input  wire [31:0] b,      // Input float B (IEEE 754 format)
    input  wire sub,    // Operation select: 0 = add, 1 = subtract
    output reg [31:0] result  // Resulting float (IEEE 754 format)
);

    // Step 1: Unpack Inputs

    wire sign_a = a[31];              // Sign bit of A
    wire sign_b = b[31] ^ sub;        // Sign bit of B, flipped if we're subtracting

    // Note: For 32-bit float, exponent bias is 127, so exp_a and exp_b are actually in range [-126, 127]
    // (originally [0,255] -> (reserved) [1,254] -> (- bias) [-126,127])
    wire [7:0] raw_exp_a = a[30:23];  // Raw exponent of A
    wire [7:0] raw_exp_b = b[30:23];  // Raw exponent of B
    
    reg [7:0] exp_a;      // Final exponent of A (adjusted if subnormal)
    reg [7:0] exp_b;      // Final exponent of B

    // TODO: Check for exponent = all 1s (infinity or NaN) (currently does check for subnormal numbers correctly)
    reg [23:0] man_a;     // Mantissa of A with implicit leading 1 if normalized
    reg [23:0] man_b;     // Mantissa of B with implicit leading 1 if normalized
    
    // Handle normalized and subnormal numbers for both operands
    always @(*) begin
        if (raw_exp_a == 8'd0) begin                  // A is subnormal
            man_a = {1'b0, a[22:0]};                  // No implicit 1
            exp_a = 8'd1;                             // Treat as exponent 1 (to allow alignment)
        end else begin                                // A is normalized
            man_a = {1'b1, a[22:0]};                  // Add implicit 1
            exp_a = raw_exp_a;
        end

        if (raw_exp_b == 8'd0) begin                  // B is subnormal
            man_b = {1'b0, b[22:0]};
            exp_b = 8'd1;
        end else begin
            man_b = {1'b1, b[22:0]};
            exp_b = raw_exp_b;
        end
    end

    // Step 2: Align Exponents

    wire [7:0] exp_diff = (exp_a >= exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);  // Difference in exponents

    // Note: Should be synthesizable via barrel shifter by Verilog
    wire [23:0] man_a_shifted = (exp_a >= exp_b) ? man_a : (man_a >> exp_diff);  // Shift A if it has smaller exponent
    wire [23:0] man_b_shifted = (exp_a >= exp_b) ? (man_b >> exp_diff) : man_b;  // Shift B if it has smaller exponent

    wire [7:0] exp_base = (exp_a >= exp_b) ? exp_a : exp_b;  // Base exponent after alignment
    
    // Step 3: Add/Subtract Aligned Mantissas

    wire [24:0] extended_a = {1'b0, man_a_shifted};   // Add leading 0 to prevent overflow
    wire [24:0] extended_b = {1'b0, man_b_shifted};

    reg [24:0] sum;         // Result of addition or subtraction
    reg sign_res;           // Final result sign

    // Perform mantissa operation depending on operand signs
    always @(*) begin
        if (sign_a == sign_b) begin
            sum = extended_a + extended_b;            // Same signs: perform addition
            sign_res = sign_a;                        // Keep common sign
        end else if (extended_a >= extended_b) begin
            sum = extended_a - extended_b;            // A > B: subtract B from A
            sign_res = sign_a;                        // Result takes A's sign
        end else begin
            sum = extended_b - extended_a;            // B > A: subtract A from B
            sign_res = sign_b;                        // Result takes B's sign
        end
    end

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
            result[30:23] = exp_base + 1;              // Exponent increments by 1
            result[22:0]  = sum[23:1];                 // Drop LSB and implicit 1
        end else begin
            shift = 8'd0;
            found = 1'b0;
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
