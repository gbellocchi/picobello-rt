// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
 
#include "dpi_dse.h"

/////////////////
// DMA control //
/////////////////

// VPI implementation to force the DMA start bit (control register file)
extern "C" void dpi_dse_dma_start(int cl_id, int noc_plane_id, int value) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_dse.dut.gen_clusters[%d].i_traffic_gen_tile.%s", 
    cl_id, tg_instance
  );

  // Construct target signal path to start
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_ctrl.reg2hw.start.q", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = dpi_dse_vpi_get_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiForceFlag);
}

// VPI implementation to read the DMA done flag (control register file)
extern "C" int dpi_dse_dma_get_idle(int cl_id, int noc_plane_id) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_dse.dut.gen_clusters[%d].i_traffic_gen_tile.%s", 
    cl_id, tg_instance
  );

  // Construct signal path to the signal
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_ctrl.hw2reg.done.d", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = dpi_dse_vpi_get_handle(vsim_path);
  if (!vpi_handle) return 0;

  // Read current done value
  s_vpi_value vpi_val;
  vpi_val.format = vpiScalarVal;
  vpi_get_value(vpi_handle, &vpi_val);
  
  return (vpi_val.value.scalar == vpi1) ? 1 : 0;
}
