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

  // DMA read control
  import "DPI-C" function void dma_read_set_arid(input int cl_id, input int core_id, input int value); 
  import "DPI-C" function void dma_read_start(input int cl_id, input int core_id, input int value, int use_hls_tg);
  import "DPI-C" function int dma_read_get_idle(input int cl_id, input int core_id, int use_hls_tg);

  // DMA write control
  import "DPI-C" function void dma_write_set_awid(input int cl_id, input int core_id, input int value);
  import "DPI-C" function void dma_write_start(input int cl_id, input int core_id, input int value, int use_hls_tg);
  import "DPI-C" function int dma_write_get_idle(input int cl_id, input int core_id, int use_hls_tg);

  // AXI Realm control
  import "DPI-C" function void axi_rt_set_fragm_len(input int cl_id, input int core_id, input int value);

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

  // Start DMA read
  task dma_read_start_high(input int cl_id, input int core_id);
    dma_read_start(cl_id, core_id, 1, fpga_picobello_pkg::UseHlsTg);
  endtask

  task dma_read_start_low(input int cl_id, input int core_id);
    dma_read_start(cl_id, core_id, 0, fpga_picobello_pkg::UseHlsTg);
  endtask

  // Wait for DMA read to become idle 
  task dma_read_wait_idle(input int cl_id, input int core_id);
    while (dma_read_get_idle(cl_id, core_id, fpga_picobello_pkg::UseHlsTg) != 1) begin
      sv_wait_clocks(1);
    end
  endtask

  // Start DMA write
  task dma_write_start_high(input int cl_id, input int core_id);
    dma_write_start(cl_id, core_id, 1, fpga_picobello_pkg::UseHlsTg);
  endtask

  task dma_write_start_low(input int cl_id, input int core_id);
    dma_write_start(cl_id, core_id, 0, fpga_picobello_pkg::UseHlsTg);
  endtask

  // Wait for DMA write to become idle 
  task dma_write_wait_idle(input int cl_id, input int core_id);
    while (dma_write_get_idle(cl_id, core_id, fpga_picobello_pkg::UseHlsTg) != 1) begin
      sv_wait_clocks(1);
    end
  endtask

  //////////////////////////////////
  //  AXI Realm control wrappers  //
  //////////////////////////////////

  task axi_rt_fragm_len(input int cl_id, input int core_id, input int value);
    axi_rt_set_fragm_len(cl_id, core_id, value);
  endtask

endmodule