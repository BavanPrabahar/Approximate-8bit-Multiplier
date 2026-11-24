# Approximate 8-bit Wallace tree multiplier: verification and synthesis flow
#
#   make            Python model + both exhaustive testbenches + synthesis report
#   make test       Python model + both exhaustive testbenches
#   make model      Python reference model: exact-tree self-check + error metrics
#   make sim        exhaustive 8x8 testbench (65,536 vectors, RTL vs Python model)
#   make sim4       exhaustive 4x4 testbench (256 vectors)
#   make sweep      error metrics vs number of approximate low columns
#   make synth      Yosys gate-level report + synthesised-netlist equivalence check
#   make wave       8x8 testbench with VCD dump (build/tb_mul_app.vcd, for GTKWave)
#   make clean
#
# Options:  MASK=00FF   APPROX_MASK of the 8x8 design under test (hex, default FFFF)
#           MASK4=0F    APPROX_MASK of the 4x4 design under test (hex, default FF)
#           IVERILOG= VVP= YOSYS= PYTHON=   tool overrides

IVERILOG ?= iverilog
VVP      ?= vvp
YOSYS    ?= yosys
PYTHON   ?= python3
MASK     ?= FFFF
MASK4    ?= FF
BUILD    := build

RTL8 := rtl/haa.v rtl/faa.v rtl/mul_app.v rtl/mul_exact_wallace.v rtl/mul_exact_8x8.v
RTL4 := rtl/haa.v rtl/faa.v rtl/compressor_4_2_approx.v rtl/mul_app_4x4.v

.PHONY: all test model sim sim4 sweep synth wave clean

all: test synth

test: model sim sim4

model:
	$(PYTHON) sim/verify_multiplier.py --mask 0x$(MASK)

sweep:
	$(PYTHON) sim/verify_multiplier.py --sweep
	$(PYTHON) sim/verify_multiplier.py --sweep --width 4

$(BUILD):
	mkdir -p $@

$(BUILD)/golden8_$(MASK).hex: sim/verify_multiplier.py | $(BUILD)
	$(PYTHON) sim/verify_multiplier.py --mask 0x$(MASK) --golden $@

$(BUILD)/golden4_$(MASK4).hex: sim/verify_multiplier.py | $(BUILD)
	$(PYTHON) sim/verify_multiplier.py --width 4 --mask 0x$(MASK4) --golden $@

sim: $(BUILD)/golden8_$(MASK).hex
	$(IVERILOG) -g2005 -Wall -Wno-timescale -o $(BUILD)/tb_mul_app.vvp \
	    "-DMASK=16'h$(MASK)" '-DGOLDEN_FILE="$<"' tb/tb_mul_app.v $(RTL8)
	$(VVP) -n $(BUILD)/tb_mul_app.vvp | tee $(BUILD)/tb_mul_app.log
	@grep -qx "TEST PASSED" $(BUILD)/tb_mul_app.log

sim4: $(BUILD)/golden4_$(MASK4).hex
	$(IVERILOG) -g2005 -Wall -Wno-timescale -o $(BUILD)/tb_mul_app_4x4.vvp \
	    "-DMASK4=8'h$(MASK4)" '-DGOLDEN_FILE="$<"' tb/tb_mul_app_4x4.v $(RTL4)
	$(VVP) -n $(BUILD)/tb_mul_app_4x4.vvp | tee $(BUILD)/tb_mul_app_4x4.log
	@grep -qx "TEST PASSED" $(BUILD)/tb_mul_app_4x4.log

synth: | $(BUILD)
	$(PYTHON) synth/report.py --yosys $(YOSYS) --keep $(BUILD)/synth | tee $(BUILD)/synth_report.md
	@grep -q "SYNTH CHECK PASSED" $(BUILD)/synth_report.md

wave: | $(BUILD)
	$(IVERILOG) -g2005 -o $(BUILD)/tb_mul_app_wave.vvp \
	    "-DMASK=16'h$(MASK)" -DDUMP tb/tb_mul_app.v $(RTL8)
	cd $(BUILD) && $(VVP) -n tb_mul_app_wave.vvp > /dev/null
	@echo "Waveform: $(BUILD)/tb_mul_app.vcd"

clean:
	rm -rf $(BUILD)
