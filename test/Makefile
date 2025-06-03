# Makefile
# Simulación con Cocotb

# Configuración por defecto
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# Lista de archivos Verilog del proyecto
PROJECT_SOURCES = \
  tt_um_JorgeArias8644.v \
  alu_8bit.v \
  alu_1bit.v \
  mux2.v \
  mux4.v \
  CLA.v \
  xor3a1n.v

ifneq ($(GATES),yes)

# Simulación RTL
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Simulación a nivel de compuertas
SIM_BUILD = sim_build/gl
COMPILE_ARGS += -DGL_TEST -DFUNCTIONAL -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Compartir configuración entre diseño y testbench
COMPILE_ARGS += -I$(SRC_DIR)

# Incluir el testbench
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# Archivo de prueba en Python
MODULE = test

# Incluir reglas de Cocotb
include $(shell cocotb-config --makefiles)/Makefile.sim
