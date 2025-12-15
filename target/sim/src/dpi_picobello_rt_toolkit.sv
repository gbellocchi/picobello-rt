// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import fpga_picobello_pkg::*;

module dpi_picobello_rt_toolkit (
  input logic clk,
  input logic rst_n
);

  ///////////
  //  DPI  //
  ///////////

  // hello world
  import "DPI-C" context task hello_world();

  // DMA control
  import "DPI-C" function void dma_read_start(input int cl_id, input int core_id, input int value);

  task sv_wait_clocks(
    input int unsigned num_clocks
  );
    repeat(num_clocks) @(posedge clk);
  endtask

endmodule