import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_alu_fsm_sequence(dut):
    """Test the full FSM sequence of alu_top.v"""

    # Start a 10ns period clock on dut.clk
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize all inputs
    dut.in_.value = 0
    dut.opcode.value = 0  # 0 = add
    dut.start.value = 0
    dut.rst_n.value = 1

    await Timer(1, units="ns")

    # Apply reset
    dut._log.info("Applying reset")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset complete")

    # Step 1: Trigger start in IDLE
    assert dut.state_out.value == 0, "FSM should be in IDLE before start"
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0  # One-cycle pulse
    await RisingEdge(dut.clk)

    assert dut.state_out.value == 1, "FSM should transition to LOAD_A_0"

    # Step 2: Feed operand A (4 bytes)
    for i in range(4):
        dut.in_.value = i
        await RisingEdge(dut.clk)
        dut._log.info(f"Loaded operand A byte {i}")

    # Step 3: Feed operand B (4 bytes)
    for i in range(4):
        dut.in_.value = 10 + i
        await RisingEdge(dut.clk)
        dut._log.info(f"Loaded operand B byte {i}")

    # Step 4: FSM goes to EXECUTE for 1 cycle
    await RisingEdge(dut.clk)
    dut._log.info(f"State at EXECUTE: {dut.state_out.value.integer}")
    await RisingEdge(dut.clk)  # Should be OUTPUT_0 now

    assert dut.state_out.value == 10, "Expected state OUTPUT_0"
    assert dut.done.value == 1, "Done should go high at OUTPUT_0"

    # Step 5: Read all 4 output bytes
    for i in range(4):
        await RisingEdge(dut.clk)
        dut._log.info(f"Result byte {i}: {dut.out.value.integer:02x}")

    # Step 6: Confirm IDLE again
    await RisingEdge(dut.clk)
    assert dut.state_out.value == 0, "FSM should return to IDLE after output"
