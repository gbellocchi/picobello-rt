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
  import "DPI-C" function int dma_read_get_idle(input int cl_id, input int core_id);

  // Wait a certain number of clock cycles
  task sv_wait_clocks(
    input int unsigned num_clocks
  );
    repeat(num_clocks) @(posedge clk);
  endtask

  ////////////////////////////
  //  DMA control wrappers  //
  ////////////////////////////

  // Wait for DMA read to become idle 
  // DPI C++ handles signal monitoring
  // SystemVerilog side handles time advancement
  task dma_read_wait_idle(input int cl_id, input int core_id);
    while (dma_read_get_idle(cl_id, core_id) != 1) begin
      sv_wait_clocks(1);
    end
  endtask

endmodule