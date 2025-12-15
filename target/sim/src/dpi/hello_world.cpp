// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

#include "dpi_picobello_rt.h"

/////////////////
// Hello world //
/////////////////

extern "C" char hello_world()
{
  printf("Hello, World!\n");
  return 0;
}