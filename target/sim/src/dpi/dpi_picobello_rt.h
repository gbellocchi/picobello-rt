// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

// C/C++ standard libraries
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

// VPI library for C/C++ interaction with RTL simulators 
#include "vpi_user.h"

// Function prototype declaration
extern "C" {
    // hello world
    char hello_world();
    // dma read control
    void dma_read_set_arid(int cl_id, int core_id, int value); 
    void dma_read_start(int cl_id, int core_id, int value, int use_hls_tg);
    int dma_read_get_idle(int cl_id, int core_id, int use_hls_tg);
    // dma write control
    void dma_write_set_awid(int cl_id, int core_id, int value);
    void dma_write_start(int cl_id, int core_id, int value, int use_hls_tg);
    int dma_write_get_idle(int cl_id, int core_id, int use_hls_tg);
}