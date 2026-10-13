// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
 
#include "dpi_picobello_rt.h"

////////////////////////
// VPI base functions //
////////////////////////

static vpiHandle vpi_get_handle(char vsim_path[512]) 
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

//////////////////////
// DMA read control //
//////////////////////

// VPI implementation to start DMA read
extern "C" void dma_read_start(int cl_id, int core_id, int noc_plane_id, int value) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.%s.gen_traffic_generators[%d]", 
    cl_id, tg_instance, core_id
  );

  // Construct target signal path to start
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_read.reg2hw.start.q", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = vpi_get_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiForceFlag);
}

// VPI implementation to read DMA idle status
extern "C" int dma_read_get_idle(int cl_id, int core_id, int noc_plane_id) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.%s.gen_traffic_generators[%d]", 
    cl_id, tg_instance, core_id
  );

  // Construct signal path to the signal
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_read.hw2reg.done.d", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = vpi_get_handle(vsim_path);
  if (!vpi_handle) return 0;

  // Read current done value
  s_vpi_value vpi_val;
  vpi_val.format = vpiScalarVal;
  vpi_get_value(vpi_handle, &vpi_val);
  
  return (vpi_val.value.scalar == vpi1) ? 1 : 0;
}

///////////////////////
// DMA write control //
///////////////////////

// VPI implementation to start DMA write
extern "C" void dma_write_start(int cl_id, int core_id, int noc_plane_id, int value) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.%s.gen_traffic_generators[%d]", 
    cl_id, tg_instance, core_id
  );

  // Construct target signal path to start
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_write.reg2hw.start.q", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = vpi_get_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiForceFlag);
}

// VPI implementation to read DMA idle status
extern "C" int dma_write_get_idle(int cl_id, int core_id, int noc_plane_id) 
{
  // Simulator signal path
  char vsim_path_base[512];
  char vsim_path[1024];

  // Select traffic generator instance based on NoC plane
  const char* tg_instance = (noc_plane_id == 0) ? "i_wide_axi_traffic_gen_wrapper" : "i_narrow_axi_traffic_gen_wrapper";

  // Construct base path
  snprintf(
    vsim_path_base, sizeof(vsim_path_base), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.%s.gen_traffic_generators[%d]", 
    cl_id, tg_instance, core_id
  );

  // Construct signal path to the signal
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "%s.i_reg_top_write.hw2reg.done.d", 
    vsim_path_base
  );

  // Get VPI handle
  vpiHandle vpi_handle = vpi_get_handle(vsim_path);
  if (!vpi_handle) return 0;

  // Read current done value
  s_vpi_value vpi_val;
  vpi_val.format = vpiScalarVal;
  vpi_get_value(vpi_handle, &vpi_val);
  
  return (vpi_val.value.scalar == vpi1) ? 1 : 0;
}

///////////////////////
// AXI-Realm control //
///////////////////////

// VPI implementation to set DMA AXI AWID
extern "C" void axi_rt_set_fragm_len(int cl_id, int core_id, int value) 
{
  // Simulator signal path
  char vsim_path[512];

  // Construct target signal path to fragment length
  snprintf(
    vsim_path, sizeof(vsim_path), 
    "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.i_axi_rt_unit_wide.i_axi_rt_reg_top.reg2hw.len_limit[%d].q", 
    cl_id, core_id
  );

  // "tb_picobello_fpga_fair.dut.gen_clusters[%d].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[%d].i_axi_rt_unit.fragm_len_new"

  // Get VPI handle
  vpiHandle vpi_handle = vpi_get_handle(vsim_path);
  if (!vpi_handle) return;

  // Set VPI value structure
  s_vpi_value vpi_val;
  vpi_val.format = vpiIntVal;
  vpi_val.value.integer = value;

  // Write value to signal
  vpi_put_value(vpi_handle, &vpi_val, NULL, vpiNoDelay);
}