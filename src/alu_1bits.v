module alu_1bits(
                input  at,bt,
                input  [1:0]ALUcontrol,
                output result,Z,N,C,V
               );
           wire int1,int2,int3,sum_out,cout_sum,mym;
            reg n;

           assign int1 = at & bt;
           assign int2 = at | bt;
           assign int3 = ~bt;
 
   // Instanciando multiplexor de dos entradas a 1 salida con selector de 1 bit
   mux2 mux2_1(.d0(bt),.d1(int3),.mux2_out(mym),.s(ALUcontrol[0]));
   // Instanciando Sumador de tipo Carry Lookahead Adder
   CLA Carry_Lookahead_Adder(.a(at),.b(mym),.Cin(ALUcontrol[0]),.Sum(sum_out),.Cout(cout_sum));
   // Instanciando multiplexor de 4 entradas a 1 salida con selector de 2 bits
   mux4 mux4_1(.d0(sum_out),.d1(sum_out),.d2(int1),.d3(int2),.mux4_out(result),.s(ALUcontrol));
   // Instanciando compuerta XOR de 3 entradas y 1 salida negativa
   xor_3a1n xor31 (.a1(at),.a2(bt),.a3(ALUcontrol[0]),.y2(V));
    
    always @* begin 
       Z = ~& result;
       C = ~ALUcontrol[1] & cout_sum;
    end
                
endmodule
