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
    tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;
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

    ////////////////////////
    // Test: Run Them All //
    ////////////////////////

    $display ("[%0tns] Test: Run Them All", $time);

    // Iterate traffic generators and memory tiles to test NoC paths
    mem_tile_loop: for (int i_mem = 0; i_mem < picobello_pkg::NumMemTiles; i_mem++) begin
      
      // ---------------------------------------------------------------------------- //

      // Set memory address
      tb_tg_cfg.mem_port_id               = i_mem;  
      tb_tg_cfg.mem_addr_base             = 32'hD000_0000 + i_mem * 32'h0010_0000;

      // Set traffic generator parameters
      tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
      tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;

      // ---------------------------------------------------------------------------- //

      // Program traffic generators (Snitch clusters)
      tg_cfg_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        // Set traffic generator address and index
        tb_tg_cfg.traffic_gen_port_id       = i_tg;
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        tb_tg_cfg.TrafficGenIdx             = i_tg;
        picobello_tg_cfg(tb_tg_cfg);
      end

      // Program traffic generators (FhgSpu)
      tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::FhgSpu;
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000;  
      tb_tg_cfg.TrafficGenIdx             = picobello_pkg::NumClusters;
      picobello_tg_cfg(tb_tg_cfg);

      // ---------------------------------------------------------------------------- //

      // Run traffic generators (Snitch clusters)
      tg_start_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_start(tb_tg_cfg);
      end

      // Run traffic generators (FhgSpu)
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000; 
      picobello_tg_start(tb_tg_cfg);

      #20us;

      // ---------------------------------------------------------------------------- //

      // Wait for termination (Snitch clusters)
      tg_wait_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_polling(tb_tg_cfg);
      end

      // Wait for termination (FhgSpu)
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000; 
      picobello_tg_polling(tb_tg_cfg);

      // ---------------------------------------------------------------------------- //

      // Print test infos (Snitch clusters)
      tg_info_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        $display ("[%0tns] - Mem-tile: %d", $time, i_mem);
        $display ("[%0tns] - TG-tile: %d", $time, i_tg);
      end
      
      // Print test infos (FhgSpu)
      $display ("[%0tns] - Mem-tile: %d", $time, i_mem);
      $display ("[%0tns] - TG-tile: %d", $time, picobello_pkg::NumClusters);

      // ---------------------------------------------------------------------------- //
    end

    #1us; 
    $finish();
  end

endmodule

