module CLA (
            input a,
            input b,
            input Cin,
            output Sum,
            output Cout
            );

    wire G;
    wire P;

    assign G = a & b;
    assign P = a ^ b;

    assign Sum = P ^ Cin;

    assign Cout = G | (P & Cin);

endmodule