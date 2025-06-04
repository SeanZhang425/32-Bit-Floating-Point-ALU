module tt_um_JorgeArias8644(

input  [7:0] ui_in,
input  [7:0] ui_in,
input  [2:0] ui_in,
output [7:0] uo_out,
input clk,
input ena,
input rst_n

);

 // Declaración de señales
 reg [7:0] a       =  ui_in[7:0]; // Input variable A de 8 bits
 reg [7:0] b       =  ui_in[7:0]; // Input variable B de 8 bits
 reg [1:0] S       =  ui_in[2:0]; // Input selector de operación 
 wire [7:0] Result = uo_out[7:0]; // Output result operations

 // Instancia del módulo alu_8bits
 alu_8bits alu_inst (
 .a(a),
 .b(b),
 .S(S),
 .Result(Result)
 );

endmodule
