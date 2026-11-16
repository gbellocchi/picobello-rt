// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

module dpi_dse (
  input logic clk,
  input logic rst_n
);

  ///////////
  //  DPI  //
  ///////////

  // hello world
  import "DPI-C" context task dpi_dse_hello_world();

  // DMA control
  import "DPI-C" function void dpi_dse_dma_start(input int cl_id, input int noc_plane_id, input int value);
  import "DPI-C" function int dpi_dse_dma_get_idle(input int cl_id, input int noc_plane_id);

  // AXI-REALM control
  import "DPI-C" function void dpi_dse_realm_set_fragm_len(input int cl_id, input int value);

  // Wait a certain number of clock cycles
  task sv_wait_clocks(
    input int unsigned num_clocks
  );
    repeat(num_clocks) @(posedge clk);
  endtask

  ////////////////////////////
  //  DMA control wrappers  //
  ////////////////////////////
  
  // DPI C++ handles signal monitoring
  // SystemVerilog side handles time advancement

  // Start the DMA (force the start bit high)
  task dma_start(input int cl_id, input int noc_plane_id);
    dpi_dse_dma_start(cl_id, noc_plane_id, 1);
  endtask

  // Release the DMA start (lower the forced start bit)
  task dma_release(input int cl_id, input int noc_plane_id);
    dpi_dse_dma_start(cl_id, noc_plane_id, 0);
  endtask

  // Wait for the DMA to become idle
  task dma_wait_idle(input int cl_id, input int noc_plane_id);
    while (dpi_dse_dma_get_idle(cl_id, noc_plane_id) != 1) begin
      sv_wait_clocks(1);
    end
  endtask

  //////////////////////////////////
  //  AXI-REALM control wrappers  //
  //////////////////////////////////

  task realm_set_fragm_len(input int cl_id, input int value);
    dpi_dse_realm_set_fragm_len(cl_id, value);
  endtask

endmodule
