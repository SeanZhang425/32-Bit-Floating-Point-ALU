`default_nettype none
`inlcude "alu_8bits.v"
module tt_um_JorgeArias8644 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire clk,
    input  wire ena,
    input  wire rst_n
);

    // Señales internas
    wire [7:0] a = ui_in;         // A y B son iguales aquí, puedes ajustar si quieres usar ui_in[7:4] y ui_in[3:0]
    wire [7:0] b = ui_in;
    wire [1:0] S = ui_in[1:0];    // Selector de operación
    wire [7:0] R;                 // Resultado de la ALU

    // Instancia del módulo ALU
    alu_8bits alu_inst (
        .a(a),
        .b(b),
        .S(S),
        .Result(R)
    );

    // Asignación de salida
    assign uo_out = R;

    // No se usan los pines uio, se ponen en alta impedancia
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule
