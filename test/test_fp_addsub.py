import struct                                  # For float <-> binary conversion

import cocotb                                  # Main Cocotb library
from cocotb.triggers import Timer              # For time-based delays


PERIOD = 1000  # clock period in ns


# NOTE: cocotb handles the endianness issue, so 240 = 0x00 FF = 00000000 11111111 is inputted as a[16..0] = 00000000 11111111, and not a[16..0] = 11111111 00000000 due to little endianness represents it as 0xFF 00 in memory
# Helper function: convert Python float to 32-bit IEEE 754 bit pattern (as an integer)
def float_to_bits(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

# Helper function: convert 32-bit IEEE 754 bit pattern (as an integer) to Python float
def bits_to_float(b):
    return struct.unpack('>f', struct.pack('>I', b))[0]

# Adding two positive numbers
@cocotb.test()
async def test_simple_add(dut):
    a, b = 1.25, 2.75             # Input floats
    expected = a + b              # Expected result

    dut.a.value = float_to_bits(a)  # Apply float A in IEEE 754 bit form
    dut.b.value = float_to_bits(b)  # Apply float B in IEEE 754 bit form
    dut.sub.value = 0               # 0 = add

    await Timer(PERIOD, units='ns')      # Wait for result to settle

    result = bits_to_float(dut.result.value.integer)  # Convert result back to float
    assert abs(result - expected) < 1e-6, f"Add failed: {a} + {b} != {result}"

# Subtracting two positive numbers
@cocotb.test()
async def test_simple_sub(dut):
    a, b = 5.5, 3.25              # Input floats
    expected = a - b              # Expected result

    dut.a.value = float_to_bits(a)  # Apply A
    dut.b.value = float_to_bits(b)  # Apply B
    dut.sub.value = 1               # 1 = subtract

    await Timer(PERIOD, units='ns')      # Wait for result

    result = bits_to_float(dut.result.value.integer)  # Read output
    assert abs(result - expected) < 1e-6, f"Sub failed: {a} - {b} != {result}"

@cocotb.test()
async def test_negative_add(dut):
    a, b = -2.0, 3.0
    expected = a + b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Neg add failed: {a} + {b} != {result}"

@cocotb.test()
async def test_add_negative(dut):
    a, b = -4.67e-3, -3.14
    expected = a + b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Add neg failed: {a} + {b} != {result}"

@cocotb.test()
async def test_negative_sub(dut):
    a, b = -142.5, 32.89
    expected = a - b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 1

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Neg sub failed: {a} - {b} != {result}"

@cocotb.test()
async def test_sub_negative(dut):
    a, b = -4.67e-3, -3.14
    expected = a - b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 1

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Sub neg failed: {a} - {b} != {result}"

# Subtracting a positive number from 0.0
@cocotb.test()
async def test_zero_sub(dut):
    a, b = 0.0, 5.0
    expected = a - b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 1

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Zero sub failed: {a} - {b} != {result}"

# Testing rounding cut-off
@cocotb.test()
async def test_rounding(dut):
    a, b = 1.0, 1e-10

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert result == 1.0, f"Rounding failed: should have rouded off due to large descrepancy in exponent, but got {result}"

# Test carry over to increase exponent
@cocotb.test()
async def test_increase_exponent(dut):
    a, b = 8.0, 8.0
    expected = a + b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Increase exponent failed: {a} + {b} != {result}"

# Test decrease exponent
@cocotb.test()
async def test_increase_exponent(dut):
    a, b = 8.0, 6.0
    expected = a - b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 1

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Decrease exponent failed: {a} - {b} != {result}"

# Test add 2 subnormal numbers
@cocotb.test()
async def test_add_subnormals(dut):
    a, b = 1.234e-41, 5.678e-41  # 10^-41 is less than 2^-127, which is subnormal
    expected = a + b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Add 2 subnormal numbers failed: {a} + {b} != {result}"

# Test when the result is a subnormal number
@cocotb.test()
async def test_sub_become_subnormals(dut):
    a, b = 3.52e-38, 3.51e-38
    expected = a - b  # 10^-40 is less than 2^-127

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 1

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Normalized numbers subtract to obtain subnormal number failed: {a} - {b} != {result}"

# Test add a subnormal number to a normalized number
@cocotb.test()
async def test_add_subnormal_to_normal(dut):
    a, b = -4.67e-41, 3.4124e-37
    expected = a + b

    dut.a.value = float_to_bits(a)
    dut.b.value = float_to_bits(b)
    dut.sub.value = 0

    await Timer(PERIOD, units='ns')

    result = bits_to_float(dut.result.value.integer)
    assert abs(result - expected) < 1e-6, f"Add subnormal number to normalized number failed: {a} + {b} != {result}"
