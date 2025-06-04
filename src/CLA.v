module CLA (                         // Carry Lookahead Adder 1-bit
            input  a,                // Input vaiable a
            input  b,                // Input variable b
            input  Cin,              // Input variable Carry In          
            output Sum,              // Output variable resultado de la suma
            output Cout              // Output variable de carry out
            );

    wire G;                          // Generate
    wire P;                          // Propagate

    assign G = a & b;
    assign P = a ^ b;

    assign Sum = P ^ Cin;

    assign Cout = G | (P & Cin);

endmodule
