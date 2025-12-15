// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
 
#include "dpi_picobello_rt.h"

////////////////////////
// VPI base functions //
////////////////////////

static vpiHandle get_vpi_handle(char vsim_path[512]) 
{
  // Get VPI handle (pointer) to SystemVerilog object at the specified path
  vpiHandle vpi_handle = vpi_handle_by_name(vsim_path, NULL);

  // Check if path is invalid
  if (!vpi_handle) {
    printf("ERROR: Signal not found: %s\n", vsim_path);
    return NULL;
  }

  return vpi_handle;
}

/////////////////
// DMA control //
/////////////////

// DMA read start
extern "C" void dma_read_start(int cl_id, int core_id, int value) 
{
  // Simulator signal path
  char vsim_path[512];

  // Construct signal path to ap_start signal
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.gen_cores[%d].i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start", 
    cl_id, core_id
  );

  // Get VPI handle
  vpiHandle vpi_handle = get_vpi_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiNoDelay);
}