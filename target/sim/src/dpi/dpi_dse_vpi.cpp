// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>
 
#include "dpi_dse.h"

////////////////////////
// VPI base functions //
////////////////////////

vpiHandle dpi_dse_vpi_get_handle(char vsim_path[512]) 
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
