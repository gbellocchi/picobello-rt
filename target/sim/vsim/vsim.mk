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

VCD_VIEWER = surfer

VSIM_WLF_NAME = $(VSIM_RUN)/$(VSIM_NAME).wlf
VSIM_VCD_NAME = $(VSIM_RUN)/$(VSIM_NAME).vcd
VCD_COMMON_CMD = vcd file $(VSIM_VCD_NAME); vcd add -r /*;
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

TRAFFIC_CFG_NAME ?= $(basename $(notdir $(FLOO_CFG)))
TRAFFIC_CFG = $(VSIM_SRC)/traffic/$(TRAFFIC_CFG_NAME).yml

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
	rm -f $(dir $(TRAFFIC_CFG))*.txt

##################
# RTL simulation #
##################

.PHONY: vsim-clean vsim-compile vsim-run-create vsim-run vsim-run-batch vsim-view-wlf

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
	cd $(VSIM_RUN) && $(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) $(TB_DUT) -wlf $(VSIM_WLF_NAME) -do "$(VCD_COMMON_CMD) $(VSIM_WAVES_CMD) $(VSIM_COMMON_CMD)" &>/dev/null

vsim-run-batch:
	cd $(VSIM_RUN) && $(VSIM) -c $(VSIM_FLAGS) $(TB_DUT) -wlf $(VSIM_WLF_NAME) -do "$(VCD_COMMON_CMD) $(VSIM_COMMON_CMD) quit"

vsim-view-wlf:
	cd $(VSIM_RUN) && $(VSIM) -view $(VSIM_WLF_NAME) -do "$(VSIM_WAVES_CMD)" &>/dev/null

vsim-view-vcd:
	cd $(VSIM_RUN) && WGPU_BACKEND=gl $(VCD_VIEWER) $(VSIM_VCD_NAME) &>/dev/null