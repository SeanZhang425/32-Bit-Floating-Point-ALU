import cocotb                                  # Main Cocotb library
from cocotb.triggers import Timer              # For time-based delays
import struct                                  # For float <-> binary conversion


# Helper function: convert Python float to 32-bit IEEE 754 bit pattern
def float_to_bits(f):
    return struct.unpack('>I', struct.pack('>f', f))[0]

# Helper function: convert 32-bit IEEE 754 bit pattern to Python float
def bits_to_float(b):
    return struct.unpack('>f', struct.pack('>I', b))[0]


@cocotb.test()
async def test_simple_add(dut):
    """Test 1.25 + 2.75 = 4.0"""
    a, b = 1.25, 2.75              # Input floats
    expected = a + b              # Expected result

    dut.a.value = float_to_bits(a)  # Apply float A in IEEE 754 bit form
    dut.b.value = float_to_bits(b)  # Apply float B in IEEE 754 bit form
    dut.sub.value = 0               # 0 = add

    await Timer(1, units='ns')      # Wait for result to settle

    result = bits_to_float(dut.result.value.integer)  # Convert result back to float
    assert abs(result - expected) < 1e-6, f"Add failed: {a} + {b} != {result}"


@cocotb.test()
async def test_simple_sub(dut):
    """Test 5.5 - 3.25 = 2.25"""
    a, b = 5.5, 3.25               # Input floats
    expected = a - b              # Expected result

    dut.a.value = float_to_bits(a)  # Apply A
    dut.b.value = float_to_bits(b)  # Apply B
    dut.sub.value = 1               # 1 = subtract

    await Timer(1, units='ns')      # Wait for result

    result = bits_to_float(dut.result.value.integer)  # Read output
    assert abs(result - expected) < 1e-6, f"Sub failed: {a} - {b} != {result}"


@cocotb.test()
async def test_negative_add(dut):
    """Test -2.0 + 3.0 = 1.0"""
    a, b = -2.0, 3.0              # Mixed sign inputs
    expected = a + b

    dut.a.value = float_to_bits(a)  # Apply A
    dut.b.value = float_to_bits(b)  # Apply B
    dut.sub.value = 0               # Add

    await Timer(1, units='ns')      # Wait for computation

    result = bits_to_float(dut.result.value.integer)  # Read output
    assert abs(result - expected) < 1e-6, f"Neg add failed: {a} + {b} != {result}"


@cocotb.test()
async def test_zero_sub(dut):
    """Test 0.0 - 5.0 = -5.0"""
    a, b = 0.0, 5.0
    expected = a - b

    dut.a.value = float_to_bits(a)  # Apply A = 0.0
    dut.b.value = float_to_bits(b)  # Apply B = 5.0
    dut.sub.value = 1               # Subtract

    await Timer(1, units='ns')      # Wait for operation

    result = bits_to_float(dut.result.value.integer)  # Read result
    assert abs(result - expected) < 1e-6, f"Zero sub failed: {a} - {b} != {result}"


@cocotb.test()
async def test_rounding(dut):
    """Test float rounding: 1.00000012 + 1e-7"""
    a, b = 1.00000012, 1e-7        # Close values, tests rounding
    expected = a + b

    dut.a.value = float_to_bits(a)  # Apply A
    dut.b.value = float_to_bits(b)  # Apply B
    dut.sub.value = 0               # Add

    await Timer(1, units='ns')      # Wait for result

    result = bits_to_float(dut.result.value.integer)  # Read float result
    assert abs(result - expected) < 1e-6, f"Rounding failed: {a} + {b} != {result}"
