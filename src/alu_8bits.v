module alu_8bits(
                      input  [7:0]  a, // input a
                      input  [15:8] b, // input b
                      input  [1:0]  S, // input ALU control
                      output [7:0]  Result //output Resultado de las operaciones
                      );
    // Instanciando ALU 1-bit para el bit 0
    alu_1bit alu_bit0(.at(a[0]),.bt(b[8]),.ALUcontrol(S),.result(Result[0]));
    // Instanciando ALU 1-bit para el bit 1
    alu_1bit alu_bit1(.at(a[1]),.bt(b[9]),.ALUcontrol(S),.result(Result[1]));    
    // Instanciando ALU 1-bit para el bit 2
    alu_1bit alu_bit2(.at(a[2]),.bt(b[10]),.ALUcontrol(S),.result(Result[2]));    
    // Instanciando ALU 1-bit para el bit 3
    alu_1bit alu_bit3(.at(a[3]),.bt(b[11]),.ALUcontrol(S),.result(Result[3]));    
    // Instanciando ALU 1-bit para el bit 4
    alu_1bit alu_bit4(.at(a[4]),.bt(b[12]),.ALUcontrol(S),.result(Result[4]));    
    // Instanciando ALU 1-bit para el bit 5
    alu_1bit alu_bit5(.at(a[5]),.bt(b[13]),.ALUcontrol(S),.result(Result[5]));    
    // Instanciando ALU 1-bit para el bit 6
    alu_1bit alu_bit6(.at(a[6]),.bt(b[14]),.ALUcontrol(S),.result(Result[6]));    
    // Instanciando ALU 1-bit para el bit 7
    alu_1bit alu_bit7(.at(a[7]),.bt(b[15]),.ALUcontrol(S),.result(Result[7]));  
endmodule
