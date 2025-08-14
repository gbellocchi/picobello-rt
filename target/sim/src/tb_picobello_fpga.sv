// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define CLK_SIGNAL clk
// `define VERBOSE

`define wait_n_clk(n) repeat(n) @(posedge clk) // Delay
`define t_periph_bus 10 // core - peripheral bus - peripheral (10)
`define t_multi_cl_displacement 16 + 96 // assuming protocol conversion (10) + sequential transmission (x16) x worst-case assumption (6)

import fpga_picobello_pkg::*;

module tb_picobello_fpga #(
  // TB timing
  localparam time ClkPeriod = 10ns, // Clock period
  parameter time ApplTime = 100ps, // Delay value assignment
  parameter time TestTime = 500ps, // Delay transaction start
  // TG parameters
  localparam time TgBurstLength = 128 // [Beats]
) (
  // Clock and reset
  input  logic clk,
  input  logic rst_n,
  // Host signals
  input fpga_picobello_pkg::axi_host_req_t tb_axi_host_req_i,
  output fpga_picobello_pkg::axi_host_rsp_t tb_axi_host_rsp_o,
  // Traffic generator configuration
  input fpga_picobello_pkg::tg_cfg_t tb_tg_cfg_read,
  input fpga_picobello_pkg::tg_cfg_t tb_tg_cfg_write,
  // AXI-Realm configuration
  input axi_rt_reg_pkg::axi_rt_reg2hw_t tb_rt_wide_cfg
);
  `include "tb_picobello_fpga_tasks.svh"
  `include "tb_picobello_rt_tasks.svh"
  
  // Timer configuration
  fpga_picobello_pkg::timer_cfg_t tb_timer_cfg;
  logic target_reached_o; // Comparator value flag
  logic [31:0] tb_timer_cnt_value, tb_timer_cnt_value_old; // Experiment latency

  // DMA in
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_r_first_burst; // first burst flag
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_r_timer_0, dma_r_timer_1, dma_r_timer_val; // timers

  // DMA write
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_w_timer_0, dma_w_timer_1, dma_w_timer_val; // timers

  // Compute
  logic [picobello_pkg::NumClusters-1:0] compute_first_burst, compute_done; // done flag
  logic [picobello_pkg::NumClusters-1:0][31:0] n_compute; // number of compute operations
  logic [picobello_pkg::NumClusters-1:0][31:0] comp_timer_0, comp_timer_1, comp_timer_val; // timers

  // SoC
  logic [picobello_pkg::NumClusters-1:0] multi_cl_done; // done flag

  // Clusters
  localparam logic [5:0] cluster_sam_offset = floo_picobello_noc_pkg::ClusterX0Y0SamIdx;
  floo_picobello_noc_pkg::sam_rule_t cluster_sam;
  floo_picobello_noc_pkg::id_t cluster_idx;

  // AXI-Realm
  logic [picobello_pkg::NumClusters-1:0] rt_configured; // configuration flag
  fpga_picobello_pkg::slv_id_t rt_reg_id [picobello_pkg::NumClusters-1:0]; // corresponding to the cluster tile id

  // Exploration variables 

  // Number of performed tests
  int NTest;
  // Number of cluster under test
  int NTestCl;
  // Number of operations per cluster
  int NOps, NOpsMin, NOpsMax;
  // Number of cluster tiles per memory tile
  int NClXMem, NClXMemMin, NClXMemMax;
  // Number of accelerators per cluster
  int NAccxCl, NAccxClMin, NAccxClMax;

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

  // Clock and reset generation
  clk_rst_gen #(
    .ClkPeriod        (ClkPeriod),
    .RstClkCycles     (5)
  ) i_clk_gen (
    .clk_o            (clk),
    .rst_no           (rst_n)
  );

  // TB counter
  timer_unit_counter counter_i (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .write_counter_i  (tb_timer_cfg.write_counter_i),
    .counter_value_i  (tb_timer_cfg.counter_value_i),
    .reset_count_i    (tb_timer_cfg.reset_count_i),
    .enable_count_i   (tb_timer_cfg.enable_count_i),
    .compare_value_i  (tb_timer_cfg.compare_value_i),
    .counter_value_o  (tb_timer_cnt_value),
    .target_reached_o (target_reached_o)
  );

  // Program and launch traffic generators inside Picobello
  initial begin
    // Initialization - axi req
    tb_axi_host_req_i = '{default: '0};
    // Initialization - tg cfg
    tb_tg_cfg_read = '{default: '0};
    tb_tg_cfg_write = '{default: '0};
    tb_timer_cfg = '{default: '0};
    // Initialization - axi-realm
    tb_rt_wide_cfg = '{default: '0};
    rt_configured = '{default: '0};

    // Wait for reset
    wait(rst_n);
    @(posedge `CLK_SIGNAL); #5;

    /////////////////////////
    // Configure AXI-Realm //
    /////////////////////////

    // Initialize AXI-Realm IDs
    init_rt_id: for (int i = 0; i < picobello_pkg::NumClusters; i++) begin
      cluster_sam = floo_picobello_noc_pkg::Sam[i + cluster_sam_offset];
      cluster_idx = cluster_sam.idx;
      rt_reg_id[i] = cluster_idx.y + picobello_pkg::MeshDim.y * cluster_idx.x;
    end

    /////////////////////////////
    // Test: Parallel accesses //
    /////////////////////////////

    $display ("\n- Exploration test -");

    // Initialize test variables
    NTest = 0;

    NAccxClMin = 1; // 1 accelerator per cluster tile (most performant case)
    NAccxClMax = 1; // 1 <= NAccxClMax <= NumClusters

    NOpsMin = 32'h0000_0000; // Divide in two runs: Min (mem-bound): 32'h0000_0000 - Min (comp-bound): 32'h0000_8000
    NOpsMax = 32'h0000_0000; // Divide in two runs: Max (mem-bound): 32'h0000_4000 - Max (comp-bound): 32'h0200_0000

    @(posedge `CLK_SIGNAL);

    // Loop over the number of accelerators per cluster (from 1 to 16)
    n_accxcl_loop: for (NAccxCl = NAccxClMin; NAccxCl <= NAccxClMax; NAccxCl = NAccxCl * 2) begin

      NTestCl = picobello_pkg::NumClusters / NAccxCl; // Number of clusters under test

      NClXMemMin = 1; // 1 cluster per memory tile (most performant case)
      NClXMemMax = 1; // 1 <= NClXMemMax <= NTestCl

      @(posedge `CLK_SIGNAL);

      // Loop over the number of clusters per memory tile (from 1 to 16)
      n_clxmem_loop: for (NClXMem = NClXMemMin; NClXMem <= NClXMemMax; NClXMem = NClXMem * 2) begin

        // Loop over the number of operations per cluster (geometric progression)
        n_ops_loop: for (NOps = NOpsMin; NOps <= NOpsMax; NOps = (NOps == 0) ? 32 : NOps * 2) begin

          // Set operational intensity
          tb_tg_cfg_read.TrafficGenTrafficDim        = 32'h0000_1000; // DMA payload size (constant)
          tb_tg_cfg_read.TrafficGenComputeDim        = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)

          tb_tg_cfg_write.TrafficGenTrafficDim       = 32'h0000_1000; // DMA payload size (constant)
          tb_tg_cfg_write.TrafficGenComputeDim       = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)

          @(posedge `CLK_SIGNAL);

          // Program traffic generators
          cl_cfg_loop: for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            // Configure read traffic generator
            tb_tg_cfg_read.mem_port_id               = cl_id / NClXMem;  
            tb_tg_cfg_read.mem_addr_base             = 32'hD000_0000 + tb_tg_cfg_read.mem_port_id * 32'h0010_0000;

            tb_tg_cfg_read.traffic_gen_port_id       = cl_id;
            tb_tg_cfg_read.traffic_gen_addr_base     = 32'hC000_0000 + cl_id * 32'h0004_0000;  
            tb_tg_cfg_read.TrafficGenIdx             = cl_id;
            picobello_tg_cfg(tb_tg_cfg_read);

            // Configure write traffic generator
            tb_tg_cfg_write.mem_port_id              = cl_id / NClXMem;  
            tb_tg_cfg_write.mem_addr_base            = 32'hD100_0000 + tb_tg_cfg_write.mem_port_id * 32'h0010_0000;

            tb_tg_cfg_write.traffic_gen_port_id      = cl_id;
            tb_tg_cfg_write.traffic_gen_addr_base    = 32'hC000_2000 + cl_id * 32'h0004_0000;    
            tb_tg_cfg_write.TrafficGenIdx            = cl_id;
            picobello_tg_cfg(tb_tg_cfg_write);

            @(posedge `CLK_SIGNAL);
          end

          @(posedge `CLK_SIGNAL); #5;

          // Initialize timer
          picobello_reset_timer(tb_timer_cfg);

          // Reset old timer counter value
          tb_timer_cnt_value_old = '0; // Reset old counter value

          @(posedge `CLK_SIGNAL);

          // Start timer
          picobello_start_timer(tb_timer_cfg);

          `wait_n_clk(`t_periph_bus + `t_multi_cl_displacement) // Overhead: multi-cluster synchronization

          @(posedge `CLK_SIGNAL);

          // Iterate over the accelerators per cluster
          acc_cl_loop_dma_in: for (int acc_cl_id = 0; acc_cl_id < NAccxCl; acc_cl_id++) begin

            // Initialize TB exploration variables

            // --- DMA in
            dma_r_first_burst = '{default: '0};
            dma_r_timer_0 = '{default: '0}; 
            dma_r_timer_1 = '{default: '0}; 
            dma_r_timer_val = '{default: '0};

            // --- DMA write
            dma_w_timer_0 = '{default: '0};
            dma_w_timer_1 = '{default: '0};
            dma_w_timer_val = '{default: '0};

            // --- Compute
            compute_first_burst = '{default: '0};
            compute_done = '{default: '0};
            n_compute = '{default: '0};
            comp_timer_0 = '{default: '0};
            comp_timer_1 = '{default: '0};
            comp_timer_val = '{default: '0};

            // --- SoC
            multi_cl_done = '{default: '0};

            // DMA-in: read data from L2 memory
            // $display ("\nTest #%0d-------------DMA-in: read data from L2 memory", NTest);
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              case (cl_id)
                0: dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                1: dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                2: dut.gen_clusters[2].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                3: dut.gen_clusters[3].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                4: dut.gen_clusters[4].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                5: dut.gen_clusters[5].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                6: dut.gen_clusters[6].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                7: dut.gen_clusters[7].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                8: dut.gen_clusters[8].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                9: dut.gen_clusters[9].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                10: dut.gen_clusters[10].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                11: dut.gen_clusters[11].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                12: dut.gen_clusters[12].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                13: dut.gen_clusters[13].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                14: dut.gen_clusters[14].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
                15: dut.gen_clusters[15].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = 1'h1;
              endcase
              dma_r_timer_0[cl_id] = tb_timer_cnt_value; // Store timer value as dma read starts
            end

            `wait_n_clk(`t_periph_bus); // Overhead: dma programming time (cluster peripheral bus)

            // DMA-in: wait first burst completion
            // $display ("\nTest #%0d-------------DMA-in: wait first burst completion", NTest);
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              case (cl_id)
                0: while(dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                1: while(dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                2: while(dut.gen_clusters[2].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                3: while(dut.gen_clusters[3].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                4: while(dut.gen_clusters[4].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                5: while(dut.gen_clusters[5].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                6: while(dut.gen_clusters[6].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                7: while(dut.gen_clusters[7].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                8: while(dut.gen_clusters[8].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                9: while(dut.gen_clusters[9].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                10: while(dut.gen_clusters[10].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                11: while(dut.gen_clusters[11].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                12: while(dut.gen_clusters[12].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                13: while(dut.gen_clusters[13].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                14: while(dut.gen_clusters[14].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
                15: while(dut.gen_clusters[15].i_cluster_tg_tile.i_axi_hls_tg_wrapper.axi_tg_wide_out.r_last != 1) begin dma_r_first_burst[cl_id] = 0; @(posedge `CLK_SIGNAL); end
              endcase
              dma_r_first_burst[cl_id] = 1;
            end

            @(posedge `CLK_SIGNAL);

            // DMA-in: wait for completion
            // $display ("\nTest #%0d-------------DMA-in: wait for completion", NTest);
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              case (cl_id)
                0:  while(dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                1:  while(dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                2:  while(dut.gen_clusters[2].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                3:  while(dut.gen_clusters[3].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                4:  while(dut.gen_clusters[4].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                5:  while(dut.gen_clusters[5].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                6:  while(dut.gen_clusters[6].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                7:  while(dut.gen_clusters[7].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                8:  while(dut.gen_clusters[8].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                9:  while(dut.gen_clusters[9].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                10: while(dut.gen_clusters[10].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                11: while(dut.gen_clusters[11].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                12: while(dut.gen_clusters[12].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                13: while(dut.gen_clusters[13].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                14: while(dut.gen_clusters[14].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                15: while(dut.gen_clusters[15].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
              endcase
              // Store timer value as dma read terminates
              dma_r_timer_1[cl_id] = tb_timer_cnt_value;
              dma_r_timer_val[cl_id] = dma_r_timer_1[cl_id] - dma_r_timer_0[cl_id];
            end

            @(posedge `CLK_SIGNAL);

          end // n_accxcl_loop_dma_in

          // Do not need to iterate on computations because these are running in parallel inside the cluster as soon as data arrive

          // Compute: run
          // $display ("\nTest #%0d-------------Compute: run", NTest);
          for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            if(dma_r_first_burst[cl_id]) begin
              comp_timer_0[cl_id] = tb_timer_cnt_value; // Store timer value as computation starts
            end
          end

          `wait_n_clk(`t_periph_bus); // Overhead: accelerator programming time (cluster peripheral bus)

          // Compute: wait for computation of first data burst
          // $display ("\nTest #%0d-------------Compute: wait for computation of first data burst", NTest);
          for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            while(!compute_first_burst[cl_id]) begin
              
              // Store timer value as computation of first data burst terminates
              comp_timer_1[cl_id] = tb_timer_cnt_value;
              comp_timer_val[cl_id] = comp_timer_1[cl_id] - comp_timer_0[cl_id];

              @(posedge `CLK_SIGNAL);

              // Set flag after computation
              if(comp_timer_val[cl_id] >= TgBurstLength) begin
                compute_first_burst[cl_id] = 1'b1; 
              end
            end
          end

          @(posedge `CLK_SIGNAL);

          // Compute: wait for completion
          // $display ("\nTest #%0d-------------Compute: wait for completion", NTest);
          for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
            while(!compute_done[cl_id]) begin
              
              // Store timer value as computation terminates
              comp_timer_1[cl_id] = tb_timer_cnt_value;
              comp_timer_val[cl_id] = comp_timer_1[cl_id] - comp_timer_0[cl_id];

              @(posedge `CLK_SIGNAL);

              // Set done flag after computation
              if(comp_timer_val[cl_id] >= (tb_tg_cfg_read.TrafficGenComputeDim)) begin
                compute_done[cl_id] = 1'b1; 
                @(posedge `CLK_SIGNAL);
              end
            end
          end

          @(posedge `CLK_SIGNAL);

          // Iterate over the accelerators per cluster
          acc_cl_loop_dma_out: for (int acc_cl_id = 0; acc_cl_id < NAccxCl; acc_cl_id++) begin

            // DMA-out: write data from L2 memory
            // $display ("\nTest #%0d-------------DMA-out: write data from L2 memory", NTest);
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              case (cl_id)
                0:  dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                1:  dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                2:  dut.gen_clusters[2].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                3:  dut.gen_clusters[3].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                4:  dut.gen_clusters[4].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                5:  dut.gen_clusters[5].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                6:  dut.gen_clusters[6].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                7:  dut.gen_clusters[7].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                8:  dut.gen_clusters[8].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                9:  dut.gen_clusters[9].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                10: dut.gen_clusters[10].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                11: dut.gen_clusters[11].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                12: dut.gen_clusters[12].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                13: dut.gen_clusters[13].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                14: dut.gen_clusters[14].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
                15: dut.gen_clusters[15].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.int_ap_start = 1'h1;
              endcase
              dma_w_timer_0[cl_id] = tb_timer_cnt_value; // Store timer value as dma write starts
            end

            `wait_n_clk(`t_periph_bus); // Overhead: dma programming time (cluster peripheral bus)

            // DMA-out: wait for completion
            // $display ("\nTest #%0d-------------DMA-out: wait for completion", NTest);
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              case (cl_id)
                0:  while(dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                1:  while(dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                2:  while(dut.gen_clusters[2].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                3:  while(dut.gen_clusters[3].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                4:  while(dut.gen_clusters[4].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                5:  while(dut.gen_clusters[5].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                6:  while(dut.gen_clusters[6].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                7:  while(dut.gen_clusters[7].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                8:  while(dut.gen_clusters[8].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                9:  while(dut.gen_clusters[9].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                10: while(dut.gen_clusters[10].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                11: while(dut.gen_clusters[11].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                12: while(dut.gen_clusters[12].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                13: while(dut.gen_clusters[13].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                14: while(dut.gen_clusters[14].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
                15: while(dut.gen_clusters[15].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_write.control_s_axi_U.ap_idle != 1) begin @(posedge `CLK_SIGNAL); end
              endcase
              // Store timer value as dma write terminates
              dma_w_timer_1[cl_id] = tb_timer_cnt_value;
              dma_w_timer_val[cl_id] = dma_w_timer_1[cl_id] - dma_w_timer_0[cl_id];

              @(posedge `CLK_SIGNAL);

              multi_cl_done[cl_id] = 1'b1;
            end

            // Multi-cluster: wait for completion (barrier)
            for (int cl_id = 0; cl_id < NTestCl; cl_id++) begin
              while (!multi_cl_done[cl_id]) begin 
                @(posedge `CLK_SIGNAL);
              end
            end

          end // n_accxcl_loop_dma_out

          // Stop and read timer
          picobello_stop_timer(tb_timer_cfg);

          @(posedge `CLK_SIGNAL);

          $display ("\n[%0tns] Test #%0d", $time, NTest);
          $display (" - NCl:            %8d", NTestCl);
          $display (" - NAccxCl:        %8d", NAccxCl);
          $display (" - NClXMem:        %8d", NClXMem);
          $display (" - NOps:           %8d", tb_tg_cfg_read.TrafficGenComputeDim);
          $display (" - TrafficDim:     %8d", tb_tg_cfg_read.TrafficGenTrafficDim);
          $display (" - ComputeDim:     %8d", tb_tg_cfg_read.TrafficGenComputeDim);

          $display (" - DmaReadTime[0]:    %8d", dma_r_timer_val[0]);
          $display (" - ComputeTime[0]:    %8d", comp_timer_val[0]);
          $display (" - DmaWriteTime[0]:   %8d", dma_w_timer_val[0]);

          $display (" - DmaReadTime[NTestCl-1]:    %8d", dma_r_timer_val[NTestCl-1]);
          $display (" - ComputeTime[NTestCl-1]:    %8d", comp_timer_val[NTestCl-1]);
          $display (" - DmaWriteTime[NTestCl-1]:   %8d", dma_w_timer_val[NTestCl-1]);
          
          $display (" - ExecTime:       %8d", tb_timer_cnt_value - tb_timer_cnt_value_old);

          NTest = NTest + 1;
          tb_timer_cnt_value_old = tb_timer_cnt_value; // Store old counter value

          @(posedge `CLK_SIGNAL);
        end // n_ops_loop
      end // n_clxmem_loop
    end // n_accxmem_loop

    #1us; 
    $finish();
  end

endmodule

