// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
 
#include "dpi_dse.h"

///////////////////////
// AXI-Realm control //
///////////////////////

// VPI implementation to set the AXI-REALM fragmentation length (len_limit)
extern "C" void dpi_dse_realm_set_fragm_len(int cl_id, int traffic_gen_id, int value) 
{
  // Simulator signal path
  char vsim_path[512];

  // Construct target signal path to fragment length
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "tb_picobello_dse.dut.gen_clusters[%d].i_traffic_gen_tile.i_axi_rt_unit_wide.i_axi_rt_reg_top.reg2hw.len_limit[%d].q", 
    cl_id, traffic_gen_id
  );

  // "tb_picobello_dse.dut.gen_clusters[%d].i_traffic_gen_tile.i_axi_rt_unit_wide.gen_rt_units[%d].i_axi_rt_unit.fragm_len_new"

  // Get VPI handle
  vpiHandle vpi_handle = dpi_dse_vpi_get_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiNoDelay);
}
