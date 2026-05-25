// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define CLK_SIGNAL clk
// `define VERBOSE

`define t_tb_wait 5 // not tide to hw functionalities
`define t_periph_bus 1 // core - peripheral bus - peripheral (10)
`define t_multi_cl_displacement 0 // assuming protocol conversion (10) + sequential transmission (x16) x worst-case assumption (6)

// Experimental results
`define PRINT_RESULTS
`define SAVE_EXPERIMENT_GENERAL
`define SAVE_EXPERIMENT_STATS
`define SAVE_BURST_TIMESTAMPS

// Traffic flow setup
// `define INTRA_FLOW   
`define INTER_FLOW_1H_ENDPOINT  
// `define INTER_FLOW_1H
// `define INTER_FLOW_2H
// `define INTER_FLOW_4H
// `define INTER_FLOW_8H

import fpga_picobello_pkg::*;
import sim_picobello_pkg::*;

module tb_picobello_fpga_fair 
  import picobello_pkg::*; 
  import floo_pkg::*; 
  import floo_picobello_noc_pkg::*; (
  input  logic clk,
  input  logic rst_n,
  // Host signals
  input fpga_picobello_pkg::axi_host_req_t tb_axi_host_req_i,
  output fpga_picobello_pkg::axi_host_rsp_t tb_axi_host_rsp_o,
  // Traffic generator configuration
  input fpga_picobello_pkg::tg_cfg_t tb_tg_cfg_read,
  input fpga_picobello_pkg::tg_cfg_t tb_tg_cfg_write,
  // AXI-Realm configuration
  input fpga_picobello_pkg::rt_cfg_t tb_rt_cfg
);
  `include "tb_picobello_sim_macros.svh"
  `include "tb_picobello_fpga_tasks.svh"
  `include "tb_picobello_rt_tasks.svh"

  ////////////////
  // TB signals //
  ////////////////

  logic [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0] end_of_sim;
  
  // Timer
  sim_picobello_pkg::timer_cfg_t tb_timer_cfg; // Timer configuration
  sim_picobello_pkg::timer_val_t t_total; // Total execution time [clock cycles]
  sim_picobello_pkg::timer_val_t t_critical; // Critical task execution time [clock cycles]
  sim_picobello_pkg::timer_val_t t_interferer; // Interferer execution time [clock cycles]
  logic target_reached_o; // Comparator value flag
  logic [31:0] tb_timer_cnt_value, tb_timer_cnt_value_old; // Timer output counter value - Experiment latency

  // BW monitoring
  fpga_picobello_pkg::axi_wide_tg_req_t bw_rt_cl_req [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  fpga_picobello_pkg::axi_wide_tg_rsp_t bw_rt_cl_rsp [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  sim_picobello_pkg::bw_monitor_cfg_t bw_rt_cl_cfg [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  sim_picobello_pkg::bw_monitor_stats_t bw_rt_cl_stats [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];

  floo_picobello_noc_pkg::axi_wide_in_req_t bw_rt_noc_ni_wide_req [picobello_pkg::NumClusters-1:0];
  floo_picobello_noc_pkg::axi_wide_in_rsp_t bw_rt_noc_ni_wide_rsp [picobello_pkg::NumClusters-1:0];
  sim_picobello_pkg::bw_monitor_cfg_t bw_rt_noc_ni_wide_cfg [picobello_pkg::NumClusters-1:0];
  sim_picobello_pkg::bw_monitor_stats_t bw_rt_noc_ni_wide_stats [picobello_pkg::NumClusters-1:0];

  floo_picobello_noc_pkg::axi_narrow_in_req_t bw_rt_noc_ni_narrow_req [picobello_pkg::NumClusters-1:0];
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t bw_rt_noc_ni_narrow_rsp [picobello_pkg::NumClusters-1:0];
  sim_picobello_pkg::bw_monitor_cfg_t bw_rt_noc_ni_narrow_cfg [picobello_pkg::NumClusters-1:0];
  sim_picobello_pkg::bw_monitor_stats_t bw_rt_noc_ni_narrow_stats [picobello_pkg::NumClusters-1:0];

  // Experimental statistics
  sim_picobello_pkg::experimental_stats_t experimental_stats;

  // DMA in
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_r_first_burst; // first burst flag
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_r_timer_0, dma_r_timer_1, dma_r_timer_val; // timers

  // DMA write
  logic [picobello_pkg::NumClusters-1:0][31:0] dma_w_timer_0, dma_w_timer_1, dma_w_timer_val; // timers

  // Compute
  logic [picobello_pkg::NumClusters-1:0] compute_first_burst, compute_done; // done flag
  logic [picobello_pkg::NumClusters-1:0][31:0] n_compute; // number of compute operations
  logic [picobello_pkg::NumClusters-1:0][31:0] comp_timer_0, comp_timer_1, comp_timer_val; // timers

  // AXI-Realm
  logic [picobello_pkg::NumClusters-1:0] rt_configured; // configuration flag
  fpga_picobello_pkg::slv_id_t rt_reg_id [picobello_pkg::NumClusters-1:0]; // corresponding to the cluster tile id
  
  // Clusters
  localparam logic [5:0] cluster_sam_offset = floo_picobello_noc_pkg::ClusterX0Y0SamIdx;
  floo_picobello_noc_pkg::sam_rule_t cluster_sam;
  floo_picobello_noc_pkg::id_t cluster_idx;

  // Cluster peripheral address map
  axi_host_addr_t core_addr_space_dim = 32'h0000_2000; // Max number of addressable masters = 32

  axi_host_addr_t cluster_addr_space_dim = ep_addr_size(floo_picobello_noc_pkg::ClusterX0Y0SamIdx);
  axi_host_addr_t many_core_addr_space_dim = core_addr_space_dim * NumCores;

  axi_host_addr_t cluster_rt_addr_dim = 32'h0000_1000;
  axi_host_addr_t cluster_dma_r_addr_dim = 32'h0000_0100;
  axi_host_addr_t cluster_dma_w_addr_dim = 32'h0000_0100;
  axi_host_addr_t cluster_compute_addr_dim = 32'h0000_0100; // not used

  axi_host_addr_t cluster_rt_addr_offset = 32'h0000_0000;
  axi_host_addr_t cluster_dma_r_addr_offset = cluster_rt_addr_offset + cluster_rt_addr_dim;
  axi_host_addr_t cluster_dma_w_addr_offset = cluster_dma_r_addr_offset + cluster_dma_r_addr_dim;
  axi_host_addr_t cluster_compute_addr_offset = cluster_dma_w_addr_offset + cluster_dma_w_addr_dim;

  // File IO
  int fileDescriptor;
  string filePath;
  string fileDir;

  /////////////////////
  // Traffic Streams //
  /////////////////////

  // DMA enable flags (use one per time)
  int DmaReadEnable = 1;
  int DmaWriteEnable = 1;

  // NoC plane control
  localparam int unsigned NumNoCPlanes = fpga_picobello_pkg::NumNoCPlanes;
  int NoCPlaneEnable[NumNoCPlanes] = '{1, 0}; // Wide=active, Narrow=inactive by default

  // Interferer reconfiguration after critical task termination
  localparam bit RuntimeInterfReconfig = 1'b0;
  int InterfBurstLengthReconfig = 32'd256; // max allowed by axi4

  // ------------------------------------------------------------- //
  // Intra-flow setup
  `ifdef INTRA_FLOW
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{
      ClusterX0Y0SamIdx, 
      ClusterX0Y1SamIdx, 
      ClusterX0Y2SamIdx, 
      ClusterX0Y3SamIdx
    };
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd1; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 1;
    localparam int unsigned NumClustersInterfActive = 0;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{ClusterX0Y0SamIdx};
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{L2Spm0SamIdx}; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd256; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 1 hop (interference at endpoint only, so 1 task per memory router port)
  `ifdef INTER_FLOW_1H_ENDPOINT
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX0Y0SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 3;
    localparam int unsigned NumClustersInterfActive = 3;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y1SamIdx, 
      ClusterX0Y2SamIdx, 
      ClusterX0Y3SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 1 hop
  `ifdef INTER_FLOW_1H
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX1Y1SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 8;
    localparam int unsigned NumClustersInterfActive = 8;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y0SamIdx,
      ClusterX0Y1SamIdx,
      ClusterX0Y2SamIdx,
      ClusterX1Y0SamIdx,
      ClusterX1Y2SamIdx,
      ClusterX2Y0SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX2Y2SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx,
      L2Spm0SamIdx, 
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 2 hops
  `ifdef INTER_FLOW_2H
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX1Y1SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 11;
    localparam int unsigned NumClustersInterfActive = 11;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y0SamIdx,
      ClusterX0Y1SamIdx,
      ClusterX0Y2SamIdx,
      ClusterX0Y3SamIdx,
      ClusterX1Y0SamIdx,
      ClusterX1Y2SamIdx,
      ClusterX1Y3SamIdx,
      ClusterX2Y0SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX2Y2SamIdx,
      ClusterX2Y3SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 4 hops
  `ifdef INTER_FLOW_4H
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX1Y1SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 17;
    localparam int unsigned NumClustersInterfActive = 17;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y0SamIdx,
      ClusterX0Y1SamIdx,
      ClusterX0Y2SamIdx,
      ClusterX0Y3SamIdx,
      ClusterX0Y4SamIdx,
      ClusterX0Y5SamIdx,
      ClusterX1Y0SamIdx,
      ClusterX1Y2SamIdx,
      ClusterX1Y3SamIdx,
      ClusterX1Y4SamIdx,
      ClusterX1Y5SamIdx,
      ClusterX2Y0SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX2Y2SamIdx,
      ClusterX2Y3SamIdx,
      ClusterX2Y4SamIdx,
      ClusterX2Y5SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 8 hops
  `ifdef INTER_FLOW_8H
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX1Y1SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Interferer flow
    localparam int unsigned NumClustersInterf = 29;
    localparam int unsigned NumClustersInterfActive = 29;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y0SamIdx,
      ClusterX0Y1SamIdx,
      ClusterX0Y2SamIdx,
      ClusterX0Y3SamIdx,
      ClusterX0Y4SamIdx,
      ClusterX0Y5SamIdx,
      ClusterX0Y6SamIdx,
      ClusterX0Y7SamIdx,
      ClusterX0Y8SamIdx,
      ClusterX0Y9SamIdx,
      ClusterX1Y0SamIdx,
      ClusterX1Y2SamIdx,
      ClusterX1Y3SamIdx,
      ClusterX1Y4SamIdx,
      ClusterX1Y5SamIdx,
      ClusterX1Y6SamIdx,
      ClusterX1Y7SamIdx,
      ClusterX1Y8SamIdx,
      ClusterX1Y9SamIdx,
      ClusterX2Y0SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX2Y2SamIdx,
      ClusterX2Y3SamIdx,
      ClusterX2Y4SamIdx,
      ClusterX2Y5SamIdx,
      ClusterX2Y6SamIdx,
      ClusterX2Y7SamIdx,
      ClusterX2Y8SamIdx,
      ClusterX2Y9SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd256; // max allowed by axi4

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //

  ///////////////////////////////
  // TB exploration variables  //
  ///////////////////////////////

  // Number of performed tests
  int NTest = 0;

  // Traffic dimension (hardwired)
  int TrafficDim = 256 * 128; // hardwired in traffic generator design

  // Number of operations per cluster
  int NOpsMin = 32'h0000_0000; // Divide in two runs: Min (mem-bound): 32'h0000_0000 - Min (comp-bound): 32'h0000_8000
  int NOpsMax = 32'h0000_0000; // Divide in two runs: Max (mem-bound): 32'h0000_4000 - Max (comp-bound): 32'h0200_0000

  // Number of cluster tiles per memory tile
  int NClXMemMin = NumClustersActive; // 1 cluster per memory tile (most performant case)
  int NClXMemMax = NumClustersActive; // 1 <= NClXMemMax <= NumClustersActive

  // Number of accelerators per cluster
  int NAccxClMin = 1; // accelerator per cluster tile (most performant case)
  int NAccxClMax = 1; // <= NAccxClMax <= NumClustersActive
  
  ///////////////////
  // Critical task //
  ///////////////////

  // Number of hops from memory tile
  localparam int unsigned NumHopsClMem = 1;

  // Number of AXI IDs per cluster
  localparam int unsigned NAxiIds = 1; 
  localparam int unsigned NAxiIdsMin = 1; // When each DMA is assigned with the same ID.
  localparam int unsigned NAxiIdsMax = NumClustersActive * NumCoresActive; // When each DMA is assigned with a unique ID.
  
  /////////
  // DUT //
  /////////

  fpga_picobello_top #(
    // Parameters
    .NumFpgaHostPorts         (fpga_picobello_pkg::NumFpgaHostPorts),  
    .NumFpgaDummyTiles        (fpga_picobello_pkg::NumFpgaDummyTiles),    
    .NumCores                 (fpga_picobello_pkg::NumCores),
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
    .ClkPeriod        (sim_picobello_pkg::ClkPeriod),
    .RstClkCycles     (5)
  ) i_clk_gen (
    .clk_o            (clk),
    .rst_no           (rst_n)
  );

  /////////////////
  // DPI toolkit //
  /////////////////

  dpi_picobello_rt_toolkit dpi_rt (
    .*
  );

  ///////////
  // Timer //
  ///////////

  // TB counter
  timer_unit_counter timer_i (
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

  ////////////////
  // BW monitor //
  ////////////////

  // Cluster wide input
  for (genvar cl_id = 0; cl_id < picobello_pkg::NumClusters; cl_id++) begin : gen_cl_bw_monitor_loop_0
    for (genvar core_id = 0; core_id < fpga_picobello_pkg::NumCores; core_id++) begin : gen_cl_bw_monitor_loop_1

      localparam string BwMonitorName = $sformatf("bw_monitor_cl_%0d_core_%0d", cl_id, core_id);

      assign bw_rt_cl_req[cl_id][core_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.axi_realm_wide_in_req[core_id];
      assign bw_rt_cl_rsp[cl_id][core_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.axi_realm_wide_in_rsp[core_id];

      axi_bw_monitor #(
        .req_t        ( fpga_picobello_pkg::axi_wide_tg_req_t           ),
        .rsp_t        ( fpga_picobello_pkg::axi_wide_tg_rsp_t           ),
        .cfg_t        ( sim_picobello_pkg::bw_monitor_cfg_t             ),
        .stat_t       ( sim_picobello_pkg::bw_monitor_stats_t           ),
        .AxiDataWidth ( fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth ),
        .AxiIdWidth   ( fpga_picobello_pkg::AxiCfgWTrafficGen.InIdWidth ),
        .Name         ( BwMonitorName                                   )
      ) i_axi_bw_monitor (
        .clk_i          ( clk                             ),
        .rst_ni         ( rst_n                           ),
        .req_i          ( bw_rt_cl_req[cl_id][core_id]    ),
        .rsp_i          ( bw_rt_cl_rsp[cl_id][core_id]    ),
        .ar_in_flight_o (                                 ),
        .aw_in_flight_o (                                 ),
        .cfg_i          ( bw_rt_cl_cfg[cl_id][core_id]    ),
        .stats_o        ( bw_rt_cl_stats[cl_id][core_id]  )
      );
    end
  end

  // FlooNoC NI AXI4 wide input
  for (genvar cl_id = 0; cl_id < picobello_pkg::NumClusters; cl_id++) begin : gen_noc_ni_bw_monitor_loop_0
    localparam string BwMonitorName = $sformatf("bw_monitor_noc_ni_wide_cl_%0d", cl_id);

    assign bw_rt_noc_ni_wide_req[cl_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.chimney_wide_in_req;
    assign bw_rt_noc_ni_wide_rsp[cl_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.chimney_wide_in_rsp;

    axi_bw_monitor #(
      .req_t        ( floo_picobello_noc_pkg::axi_wide_in_req_t       ),
      .rsp_t        ( floo_picobello_noc_pkg::axi_wide_in_rsp_t       ),
      .cfg_t        ( sim_picobello_pkg::bw_monitor_cfg_t             ),
      .stat_t       ( sim_picobello_pkg::bw_monitor_stats_t           ),
      .AxiDataWidth ( fpga_picobello_pkg::AxiCfgW.DataWidth           ),
      .AxiIdWidth   ( fpga_picobello_pkg::AxiCfgW.InIdWidth           ),
      .Name         ( BwMonitorName                                   )
    ) i_axi_bw_monitor (
      .clk_i          ( clk                             ),
      .rst_ni         ( rst_n                           ),
      .req_i          ( bw_rt_noc_ni_wide_req[cl_id]    ),
      .rsp_i          ( bw_rt_noc_ni_wide_rsp[cl_id]    ),
      .ar_in_flight_o (                                 ),
      .aw_in_flight_o (                                 ),
      .cfg_i          ( bw_rt_noc_ni_wide_cfg[cl_id]    ),
      .stats_o        ( bw_rt_noc_ni_wide_stats[cl_id]  )
    );
  end

  // FlooNoC NI AXI4 narrow input
  for (genvar cl_id = 0; cl_id < picobello_pkg::NumClusters; cl_id++) begin : gen_noc_ni_narrow_bw_monitor_loop_0
    localparam string BwMonitorName = $sformatf("bw_monitor_noc_ni_narrow_cl_%0d", cl_id);

    assign bw_rt_noc_ni_narrow_req[cl_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.chimney_narrow_in_req;
    assign bw_rt_noc_ni_narrow_rsp[cl_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.chimney_narrow_in_rsp;

    axi_bw_monitor #(
      .req_t        ( floo_picobello_noc_pkg::axi_narrow_in_req_t     ),
      .rsp_t        ( floo_picobello_noc_pkg::axi_narrow_in_rsp_t     ),
      .cfg_t        ( sim_picobello_pkg::bw_monitor_cfg_t             ),
      .stat_t       ( sim_picobello_pkg::bw_monitor_stats_t           ),
      .AxiDataWidth ( floo_picobello_noc_pkg::AxiCfgN.DataWidth       ),
      .AxiIdWidth   ( floo_picobello_noc_pkg::AxiCfgN.InIdWidth       ),
      .Name         ( BwMonitorName                                   )
    ) i_axi_bw_monitor (
      .clk_i          ( clk                                    ),
      .rst_ni         ( rst_n                                  ),
      .req_i          ( bw_rt_noc_ni_narrow_req[cl_id]         ),
      .rsp_i          ( bw_rt_noc_ni_narrow_rsp[cl_id]         ),
      .ar_in_flight_o (                                        ),
      .aw_in_flight_o (                                        ),
      .cfg_i          ( bw_rt_noc_ni_narrow_cfg[cl_id]         ),
      .stats_o        ( bw_rt_noc_ni_narrow_stats[cl_id]       )
    );
  end

  //////////////////
  // TB execution //
  //////////////////

  initial begin
    // Initialization - axi req
    tb_axi_host_req_i = '{default: '0};
    // Initialization - tg cfg
    tb_tg_cfg_read = '{default: '0};
    tb_tg_cfg_write = '{default: '0};
    tb_timer_cfg = '{default: '0};
    // Initialization - axi-realm
    tb_rt_cfg = '{default: '0};
    rt_configured = '{default: '0};
    // Initialization - bw monitors
    for (int i = 0; i < picobello_pkg::NumClusters; i++) begin
      for (int j = 0; j < fpga_picobello_pkg::NumCores; j++) begin
        bw_rt_cl_cfg[i][j] = '{default: '0};
      end
      bw_rt_noc_ni_wide_cfg[i] = '{default: '0};
      bw_rt_noc_ni_narrow_cfg[i] = '{default: '0};
    end

    // Wait for reset
    wait(rst_n);
    `wait_n_clk(`t_tb_wait);

    //////////////////////////
    // Initialize AXI-Realm //
    //////////////////////////

    // Initialize AXI-Realm IDs for critical tasks
    rt_init_id_loop: for (int i = 0; i < NumClustersActive; i++) begin
      automatic int cl_id = IdTestCl[i];
      cluster_sam = floo_picobello_noc_pkg::Sam[cl_id + cluster_sam_offset];
      cluster_idx = cluster_sam.idx;
      rt_reg_id[cl_id] = cluster_idx.y + picobello_pkg::MeshDim.y * cluster_idx.x;
    end

    // Initialize AXI-Realm IDs for interferers
    rt_interf_init_id_loop: for (int i = 0; i < NumClustersInterfActive; i++) begin
      automatic int cl_id = IdTestClInterf[i];
      cluster_sam = floo_picobello_noc_pkg::Sam[cl_id + cluster_sam_offset];
      cluster_idx = cluster_sam.idx;
      rt_reg_id[cl_id] = cluster_idx.y + picobello_pkg::MeshDim.y * cluster_idx.x;
    end

    //////////////////////////////
    // Design space exploration //
    //////////////////////////////

    // Loop over the number of accelerators per cluster
    n_acc_x_cl_loop: for (int NAccxCl = NAccxClMin; NAccxCl <= NAccxClMax; NAccxCl = NAccxCl * 2) begin

      `wait_n_clk(1);

      // Loop over the number of clusters per memory tile
      n_cl_x_mem_loop: for (int NClXMem = NClXMemMin; NClXMem <= NClXMemMax; NClXMem = NClXMem * 2) begin

        // Loop over the number of operations per cluster (geometric progression)
        n_ops_loop: for (int NOps = NOpsMin; NOps <= NOpsMax; NOps = (NOps == 0) ? 32 : NOps * 2) begin

          // Set read operational intensity
          tb_tg_cfg_read.TrafficGenTrafficDim       = TrafficDim; // DMA payload size (hardwired)
          tb_tg_cfg_read.TrafficGenComputeDim       = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)

          // Set write operational intensity
          tb_tg_cfg_write.TrafficGenTrafficDim      = TrafficDim; // DMA payload size (hardwired)
          tb_tg_cfg_write.TrafficGenComputeDim      = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)
          `wait_n_clk(1);

          // If using HLS traffic generator, then program it.
          // If using Floo DMA test node, then you do not need this because you generate traffic stream files.
          if(fpga_picobello_pkg::UseHlsTg == 1'b1) begin
            // Program traffic generators of critical tasks
            cl_cfg_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
              automatic int cl_id = IdTestCl[i];

              rt_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;
                automatic int core_axi_id;

                // Set AXI ID for DMA read
                core_axi_id = (cl_id * NumCoresActive + core_id) * (NAxiIds / NAxiIdsMax);
                for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                  dpi_rt.dma_read_set_arid(cl_id, core_id, noc_plane_id, core_axi_id);
                end

                // Configure read traffic generator
                tb_tg_cfg_read.mem_port_id               = IdTestMem;  
                tb_tg_cfg_read.mem_addr_offset           = 0;   
                tb_tg_cfg_read.mem_addr_base             = Sam[IdTestMem].start_addr;

                tb_tg_cfg_read.traffic_gen_port_id       = cl_id;
                tb_tg_cfg_read.TrafficGenIdx             = cl_id;
                tb_tg_cfg_read.traffic_gen_addr_offset   = core_id * core_addr_space_dim + cluster_dma_r_addr_offset;
                tb_tg_cfg_read.traffic_gen_addr_base     = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_tg_cfg_read.traffic_gen_addr_offset;
                
                picobello_tg_cfg(tb_tg_cfg_read);

                // Set AXI ID for DMA write
                core_axi_id = (cl_id * NumCoresActive + core_id) * (NAxiIds / NAxiIdsMax);
                for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                  dpi_rt.dma_write_set_awid(cl_id, core_id, noc_plane_id, core_axi_id);
                end

                // Configure write traffic generator
                tb_tg_cfg_write.mem_port_id              = IdTestMem;  
                tb_tg_cfg_write.mem_addr_offset          = 0;   
                tb_tg_cfg_write.mem_addr_base            = Sam[IdTestMem].start_addr;

                tb_tg_cfg_write.traffic_gen_port_id      = cl_id;
                tb_tg_cfg_write.TrafficGenIdx            = cl_id;
                tb_tg_cfg_write.traffic_gen_addr_offset  = core_id * core_addr_space_dim + cluster_dma_w_addr_offset;
                tb_tg_cfg_write.traffic_gen_addr_base    = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_tg_cfg_write.traffic_gen_addr_offset;
                
                picobello_tg_cfg(tb_tg_cfg_write);

                `wait_n_clk(1);
              end
            end

            // Program traffic generators of interferers
            cl_interf_cfg_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
              automatic int cl_id = IdTestClInterf[i];

              rt_interf_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                // Configure read traffic generator
                tb_tg_cfg_read.mem_port_id               = IdTestMemInterf[i];  
                tb_tg_cfg_read.mem_addr_offset           = 0;   
                tb_tg_cfg_read.mem_addr_base             = Sam[IdTestMemInterf[i]].start_addr;

                tb_tg_cfg_read.traffic_gen_port_id       = cl_id;
                tb_tg_cfg_read.TrafficGenIdx             = cl_id;
                tb_tg_cfg_read.traffic_gen_addr_offset   = core_id * core_addr_space_dim + cluster_dma_r_addr_offset;
                tb_tg_cfg_read.traffic_gen_addr_base     = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_tg_cfg_read.traffic_gen_addr_offset;
                
                picobello_tg_cfg(tb_tg_cfg_read);

                // Configure write traffic generator
                tb_tg_cfg_write.mem_port_id              = IdTestMemInterf[i];  
                tb_tg_cfg_write.mem_addr_offset          = 0;   
                tb_tg_cfg_write.mem_addr_base            = Sam[IdTestMemInterf[i]].start_addr;

                tb_tg_cfg_write.traffic_gen_port_id      = cl_id;
                tb_tg_cfg_write.TrafficGenIdx            = cl_id;
                tb_tg_cfg_write.traffic_gen_addr_offset  = core_id * core_addr_space_dim + cluster_dma_w_addr_offset;
                tb_tg_cfg_write.traffic_gen_addr_base    = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_tg_cfg_write.traffic_gen_addr_offset;
                
                picobello_tg_cfg(tb_tg_cfg_write);

                `wait_n_clk(1);
              end
            end
          end

          // Loop over burst length values of critical tasks (geometric progression)
          critical_task_burst_length_loop: for (int CriticalBurstLength = CriticalBurstLengthMin; CriticalBurstLength <= CriticalBurstLengthMax; CriticalBurstLength = CriticalBurstLength * 2) begin

            // Loop over burst length values of interferer tasks (geometric progression)
            interferer_task_burst_length_loop: for (int InterfBurstLength = InterfBurstLengthMin; InterfBurstLength <= InterfBurstLengthMax; InterfBurstLength = InterfBurstLength * 2) begin

              // Configure AXI-Realm for critical tasks
              rt_cfg_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];

                // Set register file address offset
                tb_rt_cfg.rt_reg_addr_offset                                            = cluster_rt_addr_offset;

                // Set register file base address
                tb_rt_cfg.rt_reg_addr_base                                              = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_rt_cfg.rt_reg_addr_offset; 

                // Initialize manager ID
                tb_rt_cfg.mgr_id                                                        = 0;

                // Set manager address space dimension
                tb_rt_cfg.mgr_addr_space_dim                                            = core_addr_space_dim;

                // Set address region - Memory tile
                tb_rt_cfg.sbr_addr_reg_id                                               = 0;

                // Set the read budget (32b)
                tb_rt_cfg.rt_regfile_cfg.read_budget[tb_rt_cfg.sbr_addr_reg_id]         = 4 * TrafficDim;
                // Set the write budget (32b)
                tb_rt_cfg.rt_regfile_cfg.write_budget[tb_rt_cfg.sbr_addr_reg_id]        = 4 * TrafficDim;

                // Set the read period (32b)
                tb_rt_cfg.rt_regfile_cfg.read_period[tb_rt_cfg.sbr_addr_reg_id]         = 4 * TrafficDim;
                // Set the write period (32b)
                tb_rt_cfg.rt_regfile_cfg.write_period[tb_rt_cfg.sbr_addr_reg_id]        = 4 * TrafficDim;

                // Set the start address (32b, low)
                tb_rt_cfg.rt_regfile_cfg.start_addr_sub_low[tb_rt_cfg.sbr_addr_reg_id]  = Sam[IdTestMem].start_addr;
                // Set the start address (32b, high)
                tb_rt_cfg.rt_regfile_cfg.start_addr_sub_high[tb_rt_cfg.sbr_addr_reg_id] = '0;
                // Set the end address (32b, low)
                tb_rt_cfg.rt_regfile_cfg.end_addr_sub_low[tb_rt_cfg.sbr_addr_reg_id]    = Sam[IdTestMem].start_addr + 32'h0010_0000;
                // Set the end address (32b, high)
                tb_rt_cfg.rt_regfile_cfg.end_addr_sub_high[tb_rt_cfg.sbr_addr_reg_id]   = '0;

                // Configure AXI-Realm guard registers
                picobello_rt_guard_init(tb_rt_cfg);

                // Configure AXI-Realm subordinate address regions
                picobello_rt_set_addr_reg(tb_rt_cfg);

                // Configure AXI-Realm period-budget QoS service
                picobello_rt_set_period_budget(tb_rt_cfg);

                // Set and configure AXI-Realm manager registers
                rt_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  // Set manager ID
                  tb_rt_cfg.mgr_id                                                    = core_id;

                  // Set the burst length limit (8b)
                  tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mgr_id]                = (CriticalBurstLength - 1) & 8'hFF;

                  // Set IMTU abort (1b)
                  tb_rt_cfg.rt_regfile_cfg.imtu_abort[tb_rt_cfg.mgr_id]               = '0;

                  // Set IMTU enable (1b)
                  tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id]              = '1;

                  // Enable real-time mode (1b)
                  tb_rt_cfg.rt_regfile_cfg.rt_enable[tb_rt_cfg.mgr_id]                = '1;

                  // Activate AXI-Realm

                  // Set burst length
                  picobello_rt_set_burst_length(tb_rt_cfg);

                  // Enable real-time mode
                  picobello_rt_enable_rt(tb_rt_cfg);
                end
              end

              // Configure AXI-Realm for interferers
              rt_interf_cfg_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
                automatic int cl_id = IdTestClInterf[i];

                // Set register file address offset
                tb_rt_cfg.rt_reg_addr_offset                                            = cluster_rt_addr_offset;

                // Set register file base address
                tb_rt_cfg.rt_reg_addr_base                                              = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_rt_cfg.rt_reg_addr_offset; 

                // Initialize manager ID
                tb_rt_cfg.mgr_id                                                        = 0;

                // Set manager address space dimension
                tb_rt_cfg.mgr_addr_space_dim                                            = core_addr_space_dim;

                // Set address region - Memory tile

                tb_rt_cfg.sbr_addr_reg_id                                               = 0;

                // Set the read budget (32b)
                tb_rt_cfg.rt_regfile_cfg.read_budget[tb_rt_cfg.sbr_addr_reg_id]         = 4 * TrafficDim;
                // Set the write budget (32b)
                tb_rt_cfg.rt_regfile_cfg.write_budget[tb_rt_cfg.sbr_addr_reg_id]        = 4 * TrafficDim;

                // Set the read period (32b)
                tb_rt_cfg.rt_regfile_cfg.read_period[tb_rt_cfg.sbr_addr_reg_id]         = 4 * TrafficDim;
                // Set the write period (32b)
                tb_rt_cfg.rt_regfile_cfg.write_period[tb_rt_cfg.sbr_addr_reg_id]        = 4 * TrafficDim;

                // Set the start address (32b, low)
                tb_rt_cfg.rt_regfile_cfg.start_addr_sub_low[tb_rt_cfg.sbr_addr_reg_id]  = Sam[IdTestMemInterf[i]].start_addr;
                // Set the start address (32b, high)
                tb_rt_cfg.rt_regfile_cfg.start_addr_sub_high[tb_rt_cfg.sbr_addr_reg_id] = '0;
                // Set the end address (32b, low)
                tb_rt_cfg.rt_regfile_cfg.end_addr_sub_low[tb_rt_cfg.sbr_addr_reg_id]    = Sam[IdTestMemInterf[i]].start_addr + 32'h0010_0000;
                // Set the end address (32b, high)
                tb_rt_cfg.rt_regfile_cfg.end_addr_sub_high[tb_rt_cfg.sbr_addr_reg_id]   = '0;

                // Configure AXI-Realm guard registers
                picobello_rt_guard_init(tb_rt_cfg);

                // Configure AXI-Realm subordinate address regions
                picobello_rt_set_addr_reg(tb_rt_cfg);

                // Configure AXI-Realm period-budget QoS service
                picobello_rt_set_period_budget(tb_rt_cfg);

                // Set and configure AXI-Realm manager registers
                rt_interf_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  // Set manager ID
                  tb_rt_cfg.mgr_id                                                    = core_id;

                  // Set the burst length limit (8b)
                  tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mgr_id]                = (InterfBurstLength - 1) & 8'hFF;

                  // Set IMTU abort (1b)
                  tb_rt_cfg.rt_regfile_cfg.imtu_abort[tb_rt_cfg.mgr_id]               = '0;
                  // Set IMTU enable (1b)
                  tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id]              = '0;

                  // Enable real-time mode (1b)
                  tb_rt_cfg.rt_regfile_cfg.rt_enable[tb_rt_cfg.mgr_id]                = '1;

                  picobello_rt_set_burst_length(tb_rt_cfg);
                  picobello_rt_enable_rt(tb_rt_cfg);
                end
              end

              `wait_n_clk(`t_tb_wait);

              // Initialize end_of_sim flag
              end_of_sim = '{default: '1};

              `wait_n_clk(1);

              // Set end_of_sim flag to 0 for active critical tasks
              // Only the critical task is monitored, interferers run in background
              init_end_of_sim_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];

                init_end_of_sim_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  end_of_sim[cl_id][core_id] = 1'b0; 
                end
              end

              `wait_n_clk(1);

              // Initialize timer
              picobello_reset_timer(tb_timer_cfg);

              // Initialize BW monitor for critical tasks
              bw_monitor_init_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];
                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
              end

              // Initialize BW monitor for interferers
              bw_interf_monitor_init_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
                automatic int cl_id = IdTestClInterf[i];
                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
              end

              // Reset old timer counter value
              tb_timer_cnt_value_old = '0; // Reset old counter value

              `wait_n_clk(1);

              // Start timer
              picobello_start_timer(tb_timer_cfg);

              `wait_n_clk(1);

              // --- DMA in
              dma_r_first_burst = '{default: '0};
              dma_r_timer_0 = '{default: '0}; 
              dma_r_timer_1 = '{default: '0}; 
              dma_r_timer_val = '{default: '0};

              // Store timer values
              t_critical.t0 = tb_timer_cnt_value;
              t_interferer.t0 = tb_timer_cnt_value;
              t_total.t0 = tb_timer_cnt_value;

              // DMA: launch data transfers to/from L2 memory
              dma_in_start_loop_0: for (int i = 0; i < (NumClustersActive + NumClustersInterfActive); i++) begin
                automatic int cl_id;
                if(i < NumClustersActive) begin
                  cl_id = IdTestCl[i];
                end else begin
                  cl_id = IdTestClInterf[i - NumClustersActive];
                end

                // Start BW monitors for NoC NI
                if(DmaReadEnable) begin
                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end
                if(DmaWriteEnable) begin
                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end

                dma_in_start_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;
                  
                  // Start DMAs
                  for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                    if(DmaReadEnable) begin
                      dpi_rt.dma_read_start_high(cl_id, core_id, noc_plane_id);
                    end
                    if(DmaWriteEnable) begin
                      dpi_rt.dma_write_start_high(cl_id, core_id, noc_plane_id);
                    end
                  end

                end
                dma_r_timer_0[cl_id] = tb_timer_cnt_value; // Store timer value as dma read starts
              end

              // DMA: lower start signal if using floo DMA test node
              if(fpga_picobello_pkg::UseHlsTg == 1'b0) begin
                
                // Wait one cycle before lowering start signal to ensure DMAs have been triggered
                `wait_n_clk(1);

                dma_in_start_low_loop_0: for (int i = 0; i < NumClustersActive + NumClustersInterfActive; i++) begin
                  automatic int cl_id;
                  if(i < NumClustersActive) begin
                    cl_id = IdTestCl[i];
                  end else begin
                    cl_id = IdTestClInterf[i - NumClustersActive];
                  end

                  dma_in_start_low_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                    automatic int core_id = j;

                    for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                      if(DmaReadEnable) begin
                        dpi_rt.dma_read_start_low(cl_id, core_id, noc_plane_id);
                      end
                      if(DmaWriteEnable) begin
                        dpi_rt.dma_write_start_low(cl_id, core_id, noc_plane_id);
                      end
                    end
                  end
                end
              end

              `wait_n_clk(5);

              // DMA: wait for completion (critical tasks only)
              dma_in_idle_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];

                dma_in_idle_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  // Wait for DMA idles
                  for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                    if(DmaReadEnable) begin
                      dpi_rt.dma_read_wait_idle(cl_id, core_id, noc_plane_id);
                    end
                    if(DmaWriteEnable) begin
                      dpi_rt.dma_write_wait_idle(cl_id, core_id, noc_plane_id);
                    end
                  end
                end
                // Store timer value as dma read terminates
                dma_r_timer_1[cl_id] = tb_timer_cnt_value;
                dma_r_timer_val[cl_id] = dma_r_timer_1[cl_id] - dma_r_timer_0[cl_id];
              end

              `wait_n_clk(1);

              // Store timer value for critical tasks
              t_critical.t1 = tb_timer_cnt_value;

              `wait_n_clk(1);

              // Reconfigure interferer clusters after critical tasks terminate
              if(RuntimeInterfReconfig) begin

                // Update and dispatch AXI-Realm configuration
                rt_interf_max_cfg_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
                  // automatic int cl_id = IdTestClInterf[i];
                  automatic int ai = i;
                  automatic int cl_id = IdTestClInterf[ai];
                  automatic fpga_picobello_pkg::rt_cfg_t local_rt_cfg = '0;

                  // programming and propagation time from host to RT unit
                  `wait_n_clk(10);

                  rt_interf_max_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                    automatic int core_id = j;

                    // Set fragment length
                    dpi_rt.axi_rt_fragm_len(cl_id, core_id, (InterfBurstLengthReconfig - 1));
                  end              
                end
              end

              // Stop BW monitors for critical tasks
              critical_task_stop_bw_monitors_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];
                if(DmaReadEnable) begin
                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end
                if(DmaWriteEnable) begin
                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end
              end

              // Wait for interferer clusters to terminate
              interferer_task_dma_in_idle_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
                automatic int cl_id = IdTestClInterf[i];
                interferer_task_dma_in_idle_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;
                  // Wait for DMA idles
                  for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
                    if(DmaReadEnable) begin
                      dpi_rt.dma_read_wait_idle(cl_id, core_id, noc_plane_id);
                    end
                    if(DmaWriteEnable) begin
                      dpi_rt.dma_write_wait_idle(cl_id, core_id, noc_plane_id);
                    end
                  end
                end                
              end  

              // Store timer value for interferer tasks
              t_interferer.t1 = tb_timer_cnt_value;

              // Store timer value for total execution time
              t_total.t1 = tb_timer_cnt_value;

              // Stop BW monitors for interferer tasks
              interferer_task_stop_bw_monitors_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
                automatic int cl_id = IdTestClInterf[i];
                if(DmaReadEnable) begin
                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end
                if(DmaWriteEnable) begin
                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
                end
              end

              // Stop timer
              picobello_stop_timer(tb_timer_cfg);

              `wait_n_clk(10);

              //////////////////////////////////
              // Display experimental results //
              //////////////////////////////////

              // Print experimental setup statistics
              experimental_stats.id_test                  = NTest;
              experimental_stats.n_cl_critical            = NumClustersActive;
              experimental_stats.n_cl_interf              = NumClustersInterfActive;
              experimental_stats.n_acc_cl                 = NAccxCl;
              experimental_stats.n_clx_mem                = NClXMem;
              experimental_stats.router_fifo_in_depth     = picobello_pkg::RouterInFifoDepth;
              experimental_stats.router_fifo_out_depth    = picobello_pkg::RouterOutFifoDepth;
              experimental_stats.ni_max_oustanding_txns   = picobello_pkg::ChimneyL2Cfg.MaxTxns;
              experimental_stats.ni_max_unique_ids        = picobello_pkg::ChimneyL2Cfg.MaxUniqueIds;
              experimental_stats.read_traffic_dim         = tb_tg_cfg_read.TrafficGenTrafficDim;
              experimental_stats.read_compute_dim         = tb_tg_cfg_read.TrafficGenComputeDim;
              experimental_stats.write_traffic_dim        = tb_tg_cfg_write.TrafficGenTrafficDim;
              experimental_stats.write_compute_dim        = tb_tg_cfg_write.TrafficGenComputeDim;
              experimental_stats.t_exec_time_ck[0]        = t_total.t1 - t_total.t0;
              experimental_stats.t_exec_time_ck[1]        = t_critical.t1 - t_critical.t0;
              experimental_stats.t_exec_time_ck[2]        = t_interferer.t1 - t_interferer.t0;

  `ifdef PRINT_RESULTS
              $display ("\n Test #%0d",                       experimental_stats.id_test);
              $display (" - SoC -- NClCritical:             %8d", experimental_stats.n_cl_critical);
              $display (" - SoC -- NClInterf:               %8d", experimental_stats.n_cl_interf);
              $display (" - SoC -- NAccCl:                  %8d", experimental_stats.n_acc_cl);
              $display (" - SoC -- NClXMem:                 %8d", experimental_stats.n_clx_mem);
              $display (" - NoC -- RouterInFifoDepth:       %8d", experimental_stats.router_fifo_in_depth);
              $display (" - NoC -- RouterOutFifoDepth:      %8d", experimental_stats.router_fifo_out_depth);
              $display (" - NoC -- NIMaxTxns:               %8d", experimental_stats.ni_max_oustanding_txns);
              $display (" - NoC -- NIMaxUniqueIds:          %8d", experimental_stats.ni_max_unique_ids);
              $display (" - Realm -- CriticalBurstLength:   %8d", CriticalBurstLength);
              $display (" - Realm -- InterfBurstLength:     %8d", InterfBurstLength);
              $display (" - Results -- TotalExecTime:       %8d", experimental_stats.t_exec_time_ck[0]);
              $display (" - Results -- CriticalExecTime:    %8d", experimental_stats.t_exec_time_ck[1]);
              $display (" - Results -- InterfExecTime:      %8d", experimental_stats.t_exec_time_ck[2]);
  `endif

              ///////////////////////////////////////
              // Save experimental results to file //
              ///////////////////////////////////////

  `ifdef SAVE_EXPERIMENT_GENERAL
              // Save experimental setup statistics to file
              if ($value$plusargs("VSIM_LOG=%s", fileDir)) begin
                // Experimental setup - Open file
                $sformat(filePath, "%s/test%0d_experimental.txt", fileDir, experimental_stats.id_test);
                // $display("Writing results to file: %s", filePath);
                fileDescriptor = $fopen(filePath, "w"); 
                // Experimental setup - Write values
                $fwrite(fileDescriptor, "id_test: %0d\n",                     experimental_stats.id_test);
                $fwrite(fileDescriptor, "n_cl_critical: %0d\n",               experimental_stats.n_cl_critical);
                $fwrite(fileDescriptor, "n_cl_interf: %0d\n",                 experimental_stats.n_cl_interf);
                $fwrite(fileDescriptor, "n_acc_cl: %0d\n",                    experimental_stats.n_acc_cl);
                $fwrite(fileDescriptor, "n_clx_mem: %0d\n",                   experimental_stats.n_clx_mem);
                $fwrite(fileDescriptor, "noc_router_fifo_in_depth: %0d\n",    experimental_stats.router_fifo_in_depth);
                $fwrite(fileDescriptor, "noc_router_fifo_out_depth: %0d\n",   experimental_stats.router_fifo_out_depth);
                $fwrite(fileDescriptor, "noc_ni_max_oustanding_txns: %0d\n",  experimental_stats.ni_max_oustanding_txns);
                $fwrite(fileDescriptor, "noc_ni_max_unique_ids: %0d\n",       experimental_stats.ni_max_unique_ids);
                $fwrite(fileDescriptor, "burst_length: %0d\n",                CriticalBurstLength);
                $fwrite(fileDescriptor, "burst_length_interf: %0d\n",         InterfBurstLength);
                $fwrite(fileDescriptor, "total_exec_time_ck: %0d\n",          experimental_stats.t_exec_time_ck[0]);
                $fwrite(fileDescriptor, "critical_exec_time_ck: %0d\n",       experimental_stats.t_exec_time_ck[1]);
                $fwrite(fileDescriptor, "interf_exec_time_ck: %0d\n",         experimental_stats.t_exec_time_ck[2]);
                // Experimental setup - Close file
                $fclose(fileDescriptor);
              end
  `endif
  `ifdef SAVE_EXPERIMENT_STATS
              // Save experiment statistics to file
              if ($value$plusargs("VSIM_LOG=%s", fileDir)) begin
                f_bw_stats_loop_0: for (int i = 0; i < (NumClustersActive + NumClustersInterfActive); i++) begin
                  automatic int cl_id;
                  if(i < NumClustersActive) begin
                    cl_id = IdTestCl[i];
                  end else begin
                    cl_id = IdTestClInterf[i - NumClustersActive];
                  end

                  // BW stats - Open file
                  $sformat(filePath, "%s/test%0d_noc_ni_statistics_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
                  // $display("Writing results to file: %s", filePath);
                  fileDescriptor = $fopen(filePath, "w"); 

                  // BW stats - Write values
                  $fwrite(fileDescriptor, "id_test: %0d\n",               experimental_stats.id_test);
                  $fwrite(fileDescriptor, "r_latency_mean: %0.2f\n",      bw_rt_noc_ni_wide_stats[cl_id].r_latency_mean);
                  $fwrite(fileDescriptor, "r_latency_stddev: %0.2f\n",    bw_rt_noc_ni_wide_stats[cl_id].r_latency_stddev);
                  $fwrite(fileDescriptor, "r_bw_mean: %0.2f\n",           bw_rt_noc_ni_wide_stats[cl_id].r_bw_mean);
                  $fwrite(fileDescriptor, "r_bw_stddev: %0.2f\n",         bw_rt_noc_ni_wide_stats[cl_id].r_bw_stddev);
                  $fwrite(fileDescriptor, "r_util_mean: %0.2f\n",         bw_rt_noc_ni_wide_stats[cl_id].r_util_mean);
                  $fwrite(fileDescriptor, "r_util_stddev: %0.2f\n",       bw_rt_noc_ni_wide_stats[cl_id].r_util_stddev);
                  $fwrite(fileDescriptor, "w_latency_mean: %0.2f\n",      bw_rt_noc_ni_wide_stats[cl_id].w_latency_mean);
                  $fwrite(fileDescriptor, "w_latency_stddev: %0.2f\n",    bw_rt_noc_ni_wide_stats[cl_id].w_latency_stddev);
                  $fwrite(fileDescriptor, "w_bw_mean: %0.2f\n",           bw_rt_noc_ni_wide_stats[cl_id].w_bw_mean);
                  $fwrite(fileDescriptor, "w_bw_stddev: %0.2f\n",         bw_rt_noc_ni_wide_stats[cl_id].w_bw_stddev);
                  $fwrite(fileDescriptor, "w_util_mean: %0.2f\n",         bw_rt_noc_ni_wide_stats[cl_id].w_util_mean);
                  $fwrite(fileDescriptor, "w_util_stddev: %0.2f\n",       bw_rt_noc_ni_wide_stats[cl_id].w_util_stddev);

                  // BW stats - Close file
                  $fclose(fileDescriptor);
                end
              end
  `endif
  `ifdef SAVE_BURST_TIMESTAMPS
              // Save burst timestamps to file
              if ($value$plusargs("VSIM_LOG=%s", fileDir)) begin
                f_latency_loop_0: for (int i = 0; i < (NumClustersActive + NumClustersInterfActive); i++) begin
                  automatic int cl_id;
                  if(i < NumClustersActive) begin
                    cl_id = IdTestCl[i];
                  end else begin
                    cl_id = IdTestClInterf[i - NumClustersActive];
                  end

                  // Latency - Open file
                  $sformat(filePath, "%s/test%0d_noc_ni_burst_stats_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
                  // $display("Writing results to file: %s", filePath);
                  fileDescriptor = $fopen(filePath, "w"); 

                  // Latency - Write header
                  $fwrite(fileDescriptor, "iter, t0, t1, lat, bw, n_beats, dw_bit\n");

                  // Latency - Write values
                  if(DmaReadEnable) begin
                    foreach (bw_rt_noc_ni_wide_stats[cl_id].r_burst_t0[i]) begin
                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
                        i,
                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_t0[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_t1[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].r_latency_val[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].r_bw_val[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_n_beats[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_dw[i]
                      );
                    end
                  end
                  if(DmaWriteEnable) begin
                    foreach (bw_rt_noc_ni_wide_stats[cl_id].w_burst_t0[i]) begin
                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
                        i,
                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_t0[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_t1[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].w_latency_val[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].w_bw_val[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_n_beats[i], 
                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_dw[i]
                      );
                    end
                  end

                  // Latency - Close file
                  $fclose(fileDescriptor);
                end
              end
  `endif

              NTest = NTest + 1;
              tb_timer_cnt_value_old = tb_timer_cnt_value; // Store old counter value

              `wait_n_clk(1);
            end // interferer_task_burst_length_loop
          end // critical_task_burst_length_loop
        end // n_ops_loop
      end // n_clxmem_loop
    end // n_accxmem_loop

    #1us; 
    $finish();
  end

  initial begin
    assert (NumCoresActive <= NumCores) else $fatal(1, "Wrong number of active cores per cluster!");
    assert (many_core_addr_space_dim <= cluster_addr_space_dim) else $fatal(1, "Cluster address space dimension exceeded!");
  end

endmodule

