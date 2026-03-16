#!/bin/bash
# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

export PICOBELLO_HOME_DIR=/scratch/gbellocchi/picobello-rt

if [ -z "$PICOBELLO_HOME_DIR" ]; then
  echo "Error: PICOBELLO_HOME_DIR is not defined." >&2
  return 1
fi

export VSIM="questa-2023.4 vsim"
export BASE_PYTHON=$PICOBELLO_HOME_DIR/.venv/bin/python
export CHS_SW_GCC_BINROOT=/usr/pack/riscv-1.0-kgf/riscv64-gcc-12.2.0/bin
export LLVM_BINROOT=/usr/scratch2/vulcano/colluca/tools/riscv32-snitch-llvm-almalinux8-15.0.0-snitch-0.1.0/bin
export VERIBLE_FMT="oseda -2025.03 verible-verilog-format"

# Create the python venv
if [ ! -d "$PICOBELLO_HOME_DIR/.venv" ]; then
  cd $PICOBELLO_HOME_DIR
  make python-venv
fi

# Activate the python venv
source "$PICOBELLO_HOME_DIR/.venv/bin/activate"
