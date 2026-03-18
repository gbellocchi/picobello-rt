# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Tim Fischer <fischeti@iis.ee.ethz.ch>
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

VSIM ?= vsim
VSIM_SRC = $(PB_ROOT)/target/sim/src
VSIM_DIR = $(PB_ROOT)/target/sim/vsim

VSIM_RUN = $(VSIM_DIR)/runs/$(VSIM_NAME)
VSIM_NAME ?= $(basename $(notdir $(FLOO_CFG)))

VSIM_WORK = $(VSIM_RUN)/work
VSIM_LOG = $(VSIM_RUN)/log

VLOG_ARGS = -work $(VSIM_WORK)
VLOG_ARGS += -suppress vlog-2583
VLOG_ARGS += -suppress vlog-13314
VLOG_ARGS += -suppress vlog-13233
VLOG_ARGS += -timescale 1ns/1ps

VSIM_FLAGS = -work $(VSIM_WORK)
VSIM_FLAGS += -suppress 3009
VSIM_FLAGS += -suppress 8386
VSIM_FLAGS += -suppress 13314
VSIM_FLAGS += -quiet
VSIM_FLAGS += -64
VSIM_FLAGS += -voptargs=+acc
VSIM_FLAGS += -voptargs=+vpi

VSIM_FLAGS_GUI = -voptargs=+acc

VCD_COMMON_CMD = vcd file $(VSIM_RUN)/tb.vcd; vcd add -r /*;
VSIM_COMMON_CMD = log -r /*; run -a;
VSIM_WAVES_CMD = source "$(VSIM_DIR)/utils/tb-waves-fpga.tcl";

define add_vsim_flag
ifdef $(1)
	VSIM_FLAGS += +$(1)=$$($(1))
endif
endef

$(eval $(call add_vsim_flag,CHS_BINARY))
$(eval $(call add_vsim_flag,SN_BINARY))
$(eval $(call add_vsim_flag,BOOTMODE))
$(eval $(call add_vsim_flag,PRELMODE))
$(eval $(call add_vsim_flag,VSIM_LOG))

######################
# Traffic Generation #
######################

TRAFFIC_GEN = $(FLOO_ROOT)/util/gen_jobs.py
TRAFFIC_TB = import_traffic_cfg
TRAFFIC_CFG ?= $(VSIM_SRC)/traffic/$(basename $(notdir $(FLOO_CFG))).yml

WIDE_BURST_NUM = 1
WIDE_BURST_LENGTH = 256
NARROW_BURST_NUM = 0
NARROW_BURST_LENGTH = 1

JOB_NAME=traffic
JOB_DIR=$(dir $(TRAFFIC_CFG))
$(eval $(call add_vsim_flag,JOB_NAME))
$(eval $(call add_vsim_flag,JOB_DIR))

vsim-jobs-create: $(TRAFFIC_CFG) $(TRAFFIC_GEN)
	@mkdir -p $(dir $(TRAFFIC_CFG))
	$(BASE_PYTHON) $(TRAFFIC_GEN) \
		--out_dir $(dir $(TRAFFIC_CFG)) \
		--tb $(TRAFFIC_TB) \
		--traffic_cfg $(TRAFFIC_CFG) \
		--floonoc_cfg $(FLOO_CFG)

vsim-jobs-clean:
	rm -rf $(dir $(TRAFFIC_CFG))

##################
# RTL simulation #
##################

.PHONY: vsim-compile vsim-clean vsim-run

vsim-clean:
	rm -rf $(VSIM_RUN)

vsim-compile: $(VSIM_RUN)/compile.tcl $(PB_HW_ALL) 
	cd $(VSIM_RUN) && $(VSIM) -c $(VSIM_FLAGS) -do "source $<; quit"

vsim-run-create:
	@if [ -d "$(VSIM_RUN)" ]; then \
		echo "Run directory already exists: $(VSIM_RUN)"; \
		read -e -p "Enter a new run name: " NEW_RUN_NAME; \
		NEW_VSIM_RUN=$(VSIM_DIR)/runs/$$NEW_RUN_NAME; \
		NEW_VSIM_LOG=$(NEW_VSIM_RUN)/log; \
		echo "Creating new run directory: $$NEW_VSIM_RUN"; \
		mkdir -p $$NEW_VSIM_LOG; \
	else \
		mkdir -p $(VSIM_LOG); \
	fi
	
$(VSIM_RUN)/compile.tcl: vsim-run-create $(BENDER_YML) $(BENDER_LOCK)
	bender script vsim --compilation-mode common $(COMMON_TARGS) $(SIM_TARGS) --vlog-arg="$(VLOG_ARGS)"> $@
	echo 'vlog -work $(VSIM_WORK) "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@
	@for DPI_FILE in $(realpath $(VSIM_SRC))/dpi/*.cpp; do \
		echo "vlog -work $(VSIM_WORK) \"$$DPI_FILE\" -ccflags \"-std=c++11\"" >> $@; \
	done

vsim-run:
	cd $(VSIM_RUN) && $(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) $(TB_DUT) -do "$(VCD_COMMON_CMD) $(VSIM_WAVES_CMD) $(VSIM_COMMON_CMD)" &>/dev/null

vsim-run-batch:
	cd $(VSIM_RUN) && $(VSIM) -c $(VSIM_FLAGS) $(TB_DUT) -do "run -all; quit"