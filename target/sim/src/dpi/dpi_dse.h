// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

#ifndef DPI_DSE_H_
#define DPI_DSE_H_

// C/C++ standard libraries
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

// VPI library for C/C++ interaction with RTL simulators
#include "vpi_user.h"

// Shared VPI helper (dpi_dse_vpi.cpp): handle of the object at a simulator path, NULL if not found
vpiHandle dpi_dse_vpi_get_handle(char vsim_path[512]);

// Function prototype declaration
extern "C" {
    // hello world
    char dpi_dse_hello_world();
    // dma read control
    void dpi_dse_dma_read_start(int cl_id, int traffic_gen_id, int noc_plane_id, int value);
    int dpi_dse_dma_read_get_idle(int cl_id, int traffic_gen_id, int noc_plane_id);
    // dma write control
    void dpi_dse_dma_write_start(int cl_id, int traffic_gen_id, int noc_plane_id, int value);
    int dpi_dse_dma_write_get_idle(int cl_id, int traffic_gen_id, int noc_plane_id);
    // axi-realm control
    void dpi_dse_realm_set_fragm_len(int cl_id, int traffic_gen_id, int value);
}

#endif // DPI_DSE_H_
