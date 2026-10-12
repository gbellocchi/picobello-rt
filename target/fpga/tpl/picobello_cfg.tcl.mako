# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Vivado project location
set prj_dir [lindex $argv 0]
puts "Vivado project is going to be located in $prj_dir\."

# Vivado parameters
set PRJ_NAME "${soc_prj_name}"
set PRJ_IP_NAME "${soc_prj_ip_name}"
set I_SOC_NAME "i_${soc_name}"
% if fpga_target == 'xilzu9eg':
# Zynq UltraScale+ ZU9EG
set PL_PART_NAME "xczu9eg-ffvb1156-2-e"
set BOARD_PART_NAME "xilinx.com:zcu102:part0:3.3"
set N_ZYNQ_MST ${n_host_ports}
set N_ZYNQ_SLV 1
% elif fpga_target == 'xilvu9p':
# Virtex UltraScale+ VU9P
set PL_PART_NAME "xcvu9p-flga2104-2L-e"
set BOARD_PART_NAME "xilinx.com:vcu118:part0:2.4"
% endif
set PL_FREQMHZ 10