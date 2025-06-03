module tt_um_JorgeArias8644(

input  [7:0] ui_in,
output [7:0] uo_out,
input  [7:0] uio_in,
output [7:0] uio_oe,
input clk,
input ena,
input rst_n

);

 // Declaración de señales
 reg [7:0] a;
 reg [7:0] b;
 reg [1:0] S;
 wire [7:0] Result;

 // Instancia del módulo alu_8bits
 alu_8bits alu_inst (
 .a(a),
 .b(b),
 .S(S),
 .Result(Result)
 );

endmodule
