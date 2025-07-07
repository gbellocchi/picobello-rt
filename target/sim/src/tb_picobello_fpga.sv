// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define CLK_SIGNAL clk
// `define VERBOSE

import fpga_picobello_pkg::*;

module tb_picobello_fpga #(
  // TB parameters
  localparam time ClkPeriod = 10ns // Clock period
) (
  // Clock and reset
  input  logic clk,
  input  logic rst_n,
  // Host signals
  input fpga_picobello_pkg::axi_host_req_t tb_axi_host_req_i,
  output fpga_picobello_pkg::axi_host_rsp_t tb_axi_host_rsp_o,
  // Traffic generator configuration
  input fpga_picobello_pkg::tg_cfg_t tb_tg_cfg,
  // Timer configuration
  input timer_cfg_t tb_timer_cfg,
  output logic [31:0] counter_value_o, // Counter value
  output logic target_reached_o // Comparator value flag
);
  `include "tb_picobello_fpga_tasks.svh"

  // Exploration variables 

  // Number of performed tests
  int NTest;
  // Number of cluster under test
  int NTestCl;
  // Number of operations per cluster
  int NOpsMin, NOpsMax;
  // Number of cluster tiles per memory tile
  int NClXMemMin, NClXMemMax;
  // Number of accelerators per cluster
  int NAccxClMin, NAccxClMax;

  // DUT
  fpga_picobello_top #(
    // Parameters
    .NumFpgaHostPorts         (fpga_picobello_pkg::NumFpgaHostPorts),  
    .NumFpgaDummyTiles        (fpga_picobello_pkg::NumFpgaDummyTiles),    
    .NumTrafficGenerators     (fpga_picobello_pkg::NumTrafficGenerators),
    // AXI4 channel types
    .axi_host_req_t           (fpga_picobello_pkg::axi_host_req_t),
    .axi_host_rsp_t           (fpga_picobello_pkg::axi_host_rsp_t),
    .axi_host_aw_chan_t       (fpga_picobello_pkg::axi_host_aw_chan_t),
    .axi_host_w_chan_t        (fpga_picobello_pkg::axi_host_w_chan_t),
    .axi_host_b_chan_t        (fpga_picobello_pkg::axi_host_b_chan_t),
    .axi_host_ar_chan_t       (fpga_picobello_pkg::axi_host_ar_chan_t),
    .axi_host_r_chan_t        (fpga_picobello_pkg::axi_host_r_chan_t),
    // AXI4-Lite channel types
    .axi_lite_host_req_t      (fpga_picobello_pkg::axi_lite_host_req_t),
    .axi_lite_host_rsp_t      (fpga_picobello_pkg::axi_lite_host_rsp_t),
    .axi_lite_host_aw_chan_t  (fpga_picobello_pkg::axi_lite_host_aw_chan_t),
    .axi_lite_host_w_chan_t   (fpga_picobello_pkg::axi_lite_host_w_chan_t),
    .axi_lite_host_b_chan_t   (fpga_picobello_pkg::axi_lite_host_b_chan_t),
    .axi_lite_host_ar_chan_t  (fpga_picobello_pkg::axi_lite_host_ar_chan_t),
    .axi_lite_host_r_chan_t   (fpga_picobello_pkg::axi_lite_host_r_chan_t)
  ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),
    .test_mode_i          (1'b0),
    .ext_axi_host_req_i   (tb_axi_host_req_i),
    .ext_axi_host_rsp_o   (tb_axi_host_rsp_o)
  );

  clk_rst_gen #(
    .ClkPeriod        (ClkPeriod),
    .RstClkCycles     (5)
  ) i_clk_gen (
    .clk_o            (clk),
    .rst_no           (rst_n)
  );

  timer_unit_counter counter_i (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .write_counter_i  (tb_timer_cfg.write_counter_i),
    .counter_value_i  (tb_timer_cfg.counter_value_i),
    .reset_count_i    (tb_timer_cfg.reset_count_i),
    .enable_count_i   (tb_timer_cfg.enable_count_i),
    .compare_value_i  (tb_timer_cfg.compare_value_i),
    .counter_value_o  (counter_value_o),
    .target_reached_o (target_reached_o)
  );

  // Program and launch traffic generators inside Picobello
  initial begin
    tb_axi_host_req_i = '{default: '0};
    tb_tg_cfg = '{default: '0};
    tb_timer_cfg = '{default: '0};

    // Wait for reset
    wait(rst_n);
    @(posedge clk); #5;

    // Initialize timer
    picobello_init_timer(tb_timer_cfg);
    wait(!tb_timer_cfg.reset_count_i); // Wait for reset to be deasserted

    //////////////////////////////////
    // Test: ClusterX0Y0 <-> L2Spm0 //
    //////////////////////////////////

    $display ("[%0tns] Test: ClusterX0Y0 <-> L2Spm0", $time);
    
    // Set address map
    tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::ClusterX0Y0;
    tb_tg_cfg.mem_port_id               = floo_picobello_noc_pkg::L2Spm0 - floo_picobello_noc_pkg::L2Spm0;
    tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + tb_tg_cfg.traffic_gen_port_id * 32'h0004_0000;    
    tb_tg_cfg.mem_addr_base             = 32'hD000_0000 + tb_tg_cfg.mem_port_id * 32'h0010_0000;

    // Set traffic generator parameters
    tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_4000;
    tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0000;
    tb_tg_cfg.TrafficGenIdx             = 32'h0000_0001;

    // Program traffic generator
    picobello_tg_cfg(tb_tg_cfg);

    // Start and read timer
    picobello_start_timer(tb_timer_cfg);

    // Run traffic generator
    picobello_tg_start(tb_tg_cfg);

    // Wait for termination
    picobello_tg_polling(tb_tg_cfg);

    // Stop and read timer
    picobello_stop_timer(tb_timer_cfg);

    $display ("[%0tns] - Timer value: %d", $time, counter_value_o);   

    /////////////////////////////
    // Test: Parallel accesses //
    /////////////////////////////

    $display ("[%0tns] Test: Parallel accesses", $time);

    // Initialize test variables
    NTest = 0;

    NAccxClMin = 1; // 1 accelerator per cluster tile (most performant case)
    NAccxClMax = picobello_pkg::NumClusters; // 1 <= NAccxClMax <= NumClusters

    NOpsMin = 32'h0000_0000;  // Divide in two runs: Min (mem-bound): 32'h0000_0000 - Min (comp-bound): 32'h0000_8000
    NOpsMax = 32'h0200_0000;  // Divide in two runs: Max (mem-bound): 32'h0000_4000 - Max (comp-bound): 32'h0200_0000

    // Loop over the number of accelerators per cluster (from 1 to 16)
    n_accxcl_loop: for (int NAccxCl = NAccxClMin; NAccxCl <= NAccxClMax; NAccxCl = NAccxCl * 2) begin

      NTestCl = picobello_pkg::NumClusters / NAccxCl; // Number of clusters under test

      NClXMemMin = 1; // 1 cluster per memory tile (most performant case)
      NClXMemMax = 1; // 1 <= NClXMemMax <= NTestCl

      // Loop over the number of clusters per memory tile (from 1 to 16)
      n_clxmem_loop: for (int NClXMem = NClXMemMin; NClXMem <= NClXMemMax; NClXMem = NClXMem * 2) begin

        // Loop over the number of operations per cluster (geometric progression)
        n_ops_loop: for (int NOps = NOpsMin; NOps <= NOpsMax; NOps = (NOps == 0) ? 32 : NOps * 2) begin

          // Set operational intensity
          tb_tg_cfg.TrafficGenTrafficDim        = 32'h0000_1000 * NAccxCl; // DMA payload size (constant)
          tb_tg_cfg.TrafficGenComputeDim        = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)

          // Program traffic generators
          cl_cfg_loop: for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            // Set memory address
            tb_tg_cfg.mem_port_id               = cl_id / NClXMem;  
            tb_tg_cfg.mem_addr_base             = 32'hD000_0000 + tb_tg_cfg.mem_port_id * 32'h0010_0000;

            // Set traffic generator address and index
            tb_tg_cfg.traffic_gen_port_id       = cl_id;
            tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + cl_id * 32'h0004_0000;  
            tb_tg_cfg.TrafficGenIdx             = cl_id;
            picobello_tg_cfg(tb_tg_cfg);

            // $display ("CL%d assigned to MEM%d", cl_id, tb_tg_cfg.mem_port_id);
          end

          // Start and read timer
          picobello_start_timer(tb_timer_cfg);

          // Run traffic generators
          cl_run_loop: for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + cl_id * 32'h0004_0000;  
            picobello_tg_start(tb_tg_cfg);
          end

          // Wait for termination
          cl_wait_loop: for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + cl_id * 32'h0004_0000;  
            picobello_tg_polling(tb_tg_cfg);
          end

          // Stop and read timer
          picobello_stop_timer(tb_timer_cfg);

          $display ("\n[%0tns] Test #%0d", $time, NTest);  
          $display (" - NCl:        %8d", NTestCl);
          $display (" - NAccxCl:    %8d", NAccxCl);
          $display (" - NClXMem:    %8d", NClXMem);
          $display (" - NOps:       %8d", NOps);
          $display (" - TrafficDim: %8d", tb_tg_cfg.TrafficGenTrafficDim);
          $display (" - ComputeDim: %8d", tb_tg_cfg.TrafficGenComputeDim);
          $display (" - ExecTime:   %8d", counter_value_o);

          NTest = NTest + 1;
        end // n_ops_loop
      end // n_clxmem_loop
    end // n_accxmem_loop

    #1us; 
    $finish();
  end

endmodule

