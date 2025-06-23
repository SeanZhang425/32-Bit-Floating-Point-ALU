# Makefile.fp_addsub.v
# Cocotb test for fp_addsub.v

# Simulator and language
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Paths
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = fp_addsub.v
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

# DUT module and Python test module (without .py extension)
TOPLEVEL = fp_addsub
MODULE = test_fp_addsub

# Compiler arguments (optional)
COMPILE_ARGS += -I$(SRC_DIR)

# Include cocotb rules
include $(shell cocotb-config --makefiles)/Makefile.sim
