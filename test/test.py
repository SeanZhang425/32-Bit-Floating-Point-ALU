import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_basic_addition(dut):
    # S = 00 (suma), a = 1, b = 2
    S = 00
    a = 1
    b = 2
#codificar en io_in: [7:0]=a [7:0]=b [1:0]=S
dut.ui_in.value = (sel << 3) | (a << 2) |b

await Timer(10,units='ns')

expected = a + b
actual = dut.uo_out.value.integer

assert actual == expected, f"Suma fallida: esperando {expected}, obtenido {actual}"
