<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Este proyecto implementa un multiplexor de 4 a 1 en Verilog, que permite seleccionar una de cuatro señales de entrada (d0, d1, d2, d3) mediante una señal de control de 2 bits (s).
La placa Basys 3 utiliza una FPGA Xilinx Artix-7, por lo que el multiplexor puede ser sintetizado y probado en hardware real. Al asignar s, la salida mux4_out tomará el valor de la entrada correspondiente.
El multiplexor puede ser útil en diversas aplicaciones, como selección de datos en sistemas digitales, procesadores, o manejo de señales en módulos más grandes.


## How to test

Para probar el módulo en la Basys 3:
- Conexión de entradas y salidas:
- Asignar d0-d3 a los switches (SW0-SW3) de la Basys 3.
- Asignar s[1] y s[0] a los switches (SW4-SW5) para controlar la selección de entrada.
- Dirigir mux4_out a un LED para visualizar el resultado.
- Compilación y síntesis:
- Escribir el código en Vivado.
- Implementar la síntesis y programar la FPGA con el archivo bitstream generado.
- Pruebas funcionales:
- Cambiar los valores de los switches y verificar que la salida en el LED corresponde con el comportamiento esperado del multiplexor.


## External hardware

- Basys 3 FPGA Board
- Built-in LEDs (para visualizar la salida mux4_out)
- Built-in switches (para manejar las entradas d0-d3 y selección s)
