// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define CLK_SIGNAL clk
// `define VERBOSE

`define wait_n_clk(n) repeat(n) @(posedge clk) // Delay
`define t_tb_wait 5 // not tide to hw functionalities
`define t_periph_bus 10 // core - peripheral bus - peripheral (10)
`define t_multi_cl_displacement 16 + 96 // assuming protocol conversion (10) + sequential transmission (x16) x worst-case assumption (6)

import fpga_picobello_pkg::*;
import sim_picobello_pkg::*;

module tb_picobello_fpga_fair 
  import picobello_pkg::*; 
  import floo_pkg::*; 
  import floo_picobello_noc_pkg::*; #(
  // TB timing
  localparam time ClkPeriod = 10ns, // Clock period
  parameter time ApplTime = 100ps, // Delay value assignment
  parameter time TestTime = 500ps, // Delay transaction start
  // TG parameters
  localparam time TgBurstLength = 128 // [Beats]
) (
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
  `include "tb_picobello_fpga_tasks.svh"
  `include "tb_picobello_rt_tasks.svh"

  ////////////////
  // TB signals //
  ////////////////

  logic [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0] end_of_sim;
  
  // Timer configuration
  fpga_picobello_pkg::timer_cfg_t tb_timer_cfg;
  logic target_reached_o; // Comparator value flag
  logic [31:0] tb_timer_cnt_value, tb_timer_cnt_value_old; // Experiment latency

  // BW monitoring
  fpga_picobello_pkg::axi_wide_tg_req_t bw_rt_cl_req [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  fpga_picobello_pkg::axi_wide_tg_rsp_t bw_rt_cl_rsp [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  sim_picobello_pkg::bw_monitor_cfg_t bw_rt_cl_cfg [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];
  sim_picobello_pkg::bw_monitor_stats_t bw_rt_cl_stats [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0];

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
  axi_host_addr_t cluster_dma_r_addr_dim = 32'h0000_0030;
  axi_host_addr_t cluster_dma_w_addr_dim = 32'h0000_0030;
  axi_host_addr_t cluster_compute_addr_dim = 32'h0000_0030; // not used

  axi_host_addr_t cluster_rt_addr_offset = 32'h0000_0000;
  axi_host_addr_t cluster_dma_r_addr_offset = cluster_rt_addr_offset + cluster_rt_addr_dim;
  axi_host_addr_t cluster_dma_w_addr_offset = cluster_dma_r_addr_offset + cluster_dma_r_addr_dim;
  axi_host_addr_t cluster_compute_addr_offset = cluster_dma_w_addr_offset + cluster_dma_w_addr_dim;

  // File IO
  int fileDescriptor;
  string filePath;
  string fileDir;

  ///////////////////////////////
  // TB exploration variables  //
  ///////////////////////////////

  // Number of performed tests
  int NTest = 0;

  // Number of test iterations (for coarser transactions)
  int NTestIterations = 1;

  // Number of clusters and cores under test
  localparam int unsigned NumClustersActive = 4;
  localparam int unsigned NumClustersInterf = 4;
  localparam int unsigned NumClustersInterfActive = 4;
  localparam int unsigned NumCoresActive = 8;

  // Traffic dimension (hardwired)
  int TrafficDim = 128 * 32; // hardwired in traffic generator design

  // Number of operations per cluster
  int NOpsMin = 32'h0000_0000; // Divide in two runs: Min (mem-bound): 32'h0000_0000 - Min (comp-bound): 32'h0000_8000
  int NOpsMax = 32'h0000_0000; // Divide in two runs: Max (mem-bound): 32'h0000_4000 - Max (comp-bound): 32'h0200_0000

  // Number of cluster tiles per memory tile
  int NClXMemMin = NumClustersActive; // 1 cluster per memory tile (most performant case)
  int NClXMemMax = NumClustersActive; // 1 <= NClXMemMax <= NumClustersActive

  // Number of accelerators per cluster
  int NAccxClMin = 1; // accelerator per cluster tile (most performant case)
  int NAccxClMax = 1; // <= NAccxClMax <= NumClusters

  ///////////////////
  // Critical task //
  ///////////////////

  // Cluster ID list for critical tasks
  // localparam int unsigned IdTestCl[NumClustersActive] = '{1, 3, 4, 6};
  localparam int unsigned IdTestCl[NumClustersActive] = '{0, 1, 2, 3};

  // Memory ID list for critical tasks
  localparam int unsigned IdTestMem = '{L2Spm0SamIdx};

  // Burst length for critical tasks
  int BurstLengthMin = 32'd1; // burstless (single-beat)
  int BurstLengthMax = 32'd128; // max allowed by axi4

  /////////////////
  // Interferers //
  /////////////////

  // Cluster ID list for interferers
  localparam int unsigned IdTestClInterf[NumClustersInterf] = '{4, 5, 6, 7};

  // Memory ID list for interferers
  localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{L2Spm1SamIdx, L2Spm2SamIdx, L2Spm3SamIdx, L2Spm4SamIdx};

  // Burst length for interferers
  int BurstLengthInterf = 32'd1; // burstless (single-beat)
  
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
    .ClkPeriod        (ClkPeriod),
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

      assign bw_rt_cl_req[cl_id][core_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.axi_realm_in_req[core_id];
      assign bw_rt_cl_rsp[cl_id][core_id] = dut.gen_clusters[cl_id].i_cluster_rt_tile.axi_realm_in_rsp[core_id];

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

      @(posedge `CLK_SIGNAL);

      // Loop over the number of clusters per memory tile
      n_cl_x_mem_loop: for (int NClXMem = NClXMemMin; NClXMem <= NClXMemMax; NClXMem = NClXMem * 2) begin

        // Loop over the number of operations per cluster (geometric progression)
        n_ops_loop: for (int NOps = NOpsMin; NOps <= NOpsMax; NOps = (NOps == 0) ? 32 : NOps * 2) begin

          // Set operational intensity
          tb_tg_cfg_read.TrafficGenTrafficDim        = TrafficDim; // DMA payload size (hardwired)
          tb_tg_cfg_read.TrafficGenComputeDim        = (NOps == 0) ? NOps : NOps + 1; // Compute time (variable)

          @(posedge `CLK_SIGNAL);

          // Program traffic generators of critical tasks
          cl_cfg_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
            automatic int cl_id = IdTestCl[i];

            rt_cfg_loop_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
              automatic int core_id = j;

              // Configure read traffic generator
              tb_tg_cfg_read.mem_port_id               = IdTestMem;  
              tb_tg_cfg_read.mem_addr_offset           = 0;   
              tb_tg_cfg_read.mem_addr_base             = Sam[IdTestMem].start_addr;

              tb_tg_cfg_read.traffic_gen_port_id       = cl_id;
              tb_tg_cfg_read.TrafficGenIdx             = cl_id;
              tb_tg_cfg_read.traffic_gen_addr_offset   = core_id * core_addr_space_dim + cluster_dma_r_addr_offset;
              tb_tg_cfg_read.traffic_gen_addr_base     = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_tg_cfg_read.traffic_gen_addr_offset;
              
              picobello_tg_cfg(tb_tg_cfg_read);

              @(posedge `CLK_SIGNAL);
            end
          end

          // Program traffic generators of interferers
          cl_interf_cfg_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
            automatic int cl_id = IdTestClInterf[i];

            rt_interf_cfg_loop_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
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

              @(posedge `CLK_SIGNAL);
            end
          end

          // Loop over burst length values (geometric progression)
          burst_length_loop: for (int BurstLength = BurstLengthMin; BurstLength <= BurstLengthMax; BurstLength = BurstLength * 2) begin

            // Configure AXI-Realm for critical tasks
            rt_cfg_loop_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
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
              rt_cfg_loop_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                // Set manager ID
                tb_rt_cfg.mgr_id                                                    = core_id;

                // Set the burst length limit (8b)
                tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mgr_id]                = (BurstLength - 1) & 8'hFF;

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

            // Configure AXI-Realm for interferers
            rt_interf_cfg_loop_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
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
              rt_interf_cfg_loop_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                // Set manager ID
                tb_rt_cfg.mgr_id                                                    = core_id;

                // Set the burst length limit (8b)
                tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mgr_id]                = (BurstLengthInterf - 1) & 8'hFF;

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

            @(posedge `CLK_SIGNAL);

            // Set end_of_sim flag to 0 for active critical tasks
            // Only the critical task is monitored, interferers run in background
            init_end_of_sim_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
              automatic int cl_id = IdTestCl[i];

              init_end_of_sim_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                end_of_sim[cl_id][core_id] = 1'b0; 
              end
            end

            @(posedge `CLK_SIGNAL);

            // Initialize timer
            picobello_reset_timer(tb_timer_cfg);

            // Initialize BW monitor for critical tasks
            bw_monitor_init_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
              automatic int cl_id = IdTestCl[i];

              bw_monitor_init_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                picobello_reset_bw_monitor(bw_rt_cl_cfg, cl_id, core_id);
              
              end
            end

            // Initialize BW monitor for interferers
            bw_interf_monitor_init_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
              automatic int cl_id = IdTestClInterf[i];

              bw_interf_monitor_init_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                automatic int core_id = j;

                picobello_reset_bw_monitor(bw_rt_cl_cfg, cl_id, core_id);
              
              end
            end

            // Reset old timer counter value
            tb_timer_cnt_value_old = '0; // Reset old counter value

            @(posedge `CLK_SIGNAL);

            // Start timer
            picobello_start_timer(tb_timer_cfg);

            // Repeat test multiple times
            test_repetition_loop: for (int test_id = 0; test_id < NTestIterations; test_id++) begin

              `wait_n_clk(`t_periph_bus + `t_multi_cl_displacement) // Overhead: multi-cluster synchronization

              @(posedge `CLK_SIGNAL);

              // Iterate over the accelerators per cluster
              dma_in_set_acc_x_cl_loop: for (int acc_cl_id = 0; acc_cl_id < NAccxCl; acc_cl_id++) begin
                // Initialize TB exploration variables

                // --- DMA in
                dma_r_first_burst = '{default: '0};
                dma_r_timer_0 = '{default: '0}; 
                dma_r_timer_1 = '{default: '0}; 
                dma_r_timer_val = '{default: '0};

                // DMA-in: read data from L2 memory
                dma_in_start_loop_0: for (int i = 0; i < (NumClustersActive + NumClustersInterfActive); i++) begin

                  automatic int cl_id;
                  if(i < NumClustersActive) begin
                    cl_id = IdTestCl[i];
                  end else begin
                    cl_id = IdTestClInterf[i - NumClustersActive];
                  end

                  dma_in_start_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                    automatic int core_id = j;
                    automatic int cluster_core_idx = cl_id * 100 + core_id;

                    if(test_id==0) begin
                      // Start BW monitor
                      picobello_start_bw_r_monitor(bw_rt_cl_cfg, cl_id, core_id);
                    end
                    
                    // Start DMA read
                    dpi_rt.dma_read_start(cl_id, core_id, 1);
                  end
                  dma_r_timer_0[cl_id] = tb_timer_cnt_value; // Store timer value as dma read starts
                end

                `wait_n_clk(`t_periph_bus); // Overhead: dma programming time (cluster peripheral bus)

                // DMA-in: wait for completion (critical tasks only)
                // $display ("\nTest #%0d-------------DMA-in: wait for completion", NTest);
                dma_in_idle_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                  automatic int cl_id = IdTestCl[i];

                  dma_in_idle_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                    automatic int core_id = j;
                    automatic int cluster_core_idx = cl_id * 100 + core_id;

                    // Wait for DMA read to be idle
                    dpi_rt.dma_read_wait_idle(cl_id, core_id);
                  end
                  // Store timer value as dma read terminates
                  dma_r_timer_1[cl_id] = tb_timer_cnt_value;
                  dma_r_timer_val[cl_id] = dma_r_timer_1[cl_id] - dma_r_timer_0[cl_id];
                end

                @(posedge `CLK_SIGNAL);

              end // dma_in_set_acc_x_cl_loop

              @(posedge `CLK_SIGNAL);

              // Iterate over the accelerators per cluster
              // Check only critical tasks, while interferers run in background
              check_idle_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];
                
                check_idle_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  if(test_id==NTestIterations-1) begin 
                    // Set barrier bit
                    end_of_sim[cl_id][core_id] = 1'b1;

                    // Stop BW monitor
                    picobello_stop_bw_r_monitor(bw_rt_cl_cfg, cl_id, core_id);
                  end
                end
              end

              // Multi-cluster idle barrier
              if(test_id==NTestIterations-1) begin 

                multi_cl_idle_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                  automatic int cl_id = IdTestCl[i];

                  multi_cl_idle_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                    automatic int core_id = j;

                    while (!end_of_sim[cl_id][core_id]) begin
                      @(posedge `CLK_SIGNAL);
                    end
                  end
                end
              end

            end // test_repetition_loop

            // Stop and read timer
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
            experimental_stats.traffic_gen_traffic_dim  = tb_tg_cfg_read.TrafficGenTrafficDim;
            experimental_stats.traffic_gen_compute_dim  = tb_tg_cfg_read.TrafficGenComputeDim;
            experimental_stats.burst_length             = BurstLength;
            experimental_stats.t_exec_time_ck           = tb_timer_cnt_value - tb_timer_cnt_value_old;

            $display ("\n Test #%0d",                       experimental_stats.id_test);
            $display (" - SoC -- NClCritical:         %8d", experimental_stats.n_cl_critical);
            $display (" - SoC -- NClInterf:           %8d", experimental_stats.n_cl_interf);
            $display (" - SoC -- NAccCl:              %8d", experimental_stats.n_acc_cl);
            $display (" - SoC -- NClXMem:             %8d", experimental_stats.n_clx_mem);
            $display (" - NoC -- RouterInFifoDepth:   %8d", experimental_stats.router_fifo_in_depth);
            $display (" - NoC -- RouterOutFifoDepth:  %8d", experimental_stats.router_fifo_out_depth);
            $display (" - NoC -- NIMaxTxns:           %8d", experimental_stats.ni_max_oustanding_txns);
            $display (" - NoC -- NIMaxUniqueIds:      %8d", experimental_stats.ni_max_unique_ids);
            $display (" - Realm -- BurstLength:       %8d", experimental_stats.burst_length);
            $display (" - Realm -- BurstLengthInterf: %8d", BurstLengthInterf);
            $display (" - Results -- ExecTime:        %8d", experimental_stats.t_exec_time_ck);

            // // Print BW monitor statistics
            // bw_monitor_display_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
            //   automatic int cl_id = IdTestCl[i];

            //   bw_monitor_display_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
            //     automatic int core_id = j;

            //     $display(
            //       "[Monitor %s][Read] Latency: %0.2f +- %0.2f Ck, BW: %0.2f +- %0.2f Bits/cycle, Util: %0.2f%% +- %0.2f",
            //       $sformatf("cl_bw_monitor_%0d_%0d", cl_id, core_id), 
            //       bw_rt_cl_stats[cl_id][core_id].r_latency_mean, 
            //       bw_rt_cl_stats[cl_id][core_id].r_latency_stddev, 
            //       bw_rt_cl_stats[cl_id][core_id].r_bw_mean, 
            //       bw_rt_cl_stats[cl_id][core_id].r_bw_stddev,
            //       bw_rt_cl_stats[cl_id][core_id].r_util_mean,
            //       bw_rt_cl_stats[cl_id][core_id].r_util_stddev
            //     );
            //     $display(
            //       "[Monitor %s][Write] Latency: %0.2f +- %0.2f Ck, BW: %0.2f +- %0.2f Bits/cycle, Util: %0.2f%% +- %0.2f",
            //       $sformatf("cl_bw_monitor_%0d_%0d", cl_id, core_id), 
            //       bw_rt_cl_stats[cl_id][core_id].w_latency_mean, 
            //       bw_rt_cl_stats[cl_id][core_id].w_latency_stddev, 
            //       bw_rt_cl_stats[cl_id][core_id].w_bw_mean, 
            //       bw_rt_cl_stats[cl_id][core_id].w_bw_stddev,
            //       bw_rt_cl_stats[cl_id][core_id].w_util_mean,
            //       bw_rt_cl_stats[cl_id][core_id].w_util_stddev
            //     );
            //   end
            // end

            ///////////////////////////////////////
            // Save experimental results to file //
            ///////////////////////////////////////

            // Save experimental setup statistics to file
            if ($value$plusargs("VSIM_LOG_CFG=%s", fileDir)) begin
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
              $fwrite(fileDescriptor, "burst_length: %0d\n",                experimental_stats.burst_length);
              $fwrite(fileDescriptor, "burst_length_interf: %0d\n",         BurstLengthInterf);
              $fwrite(fileDescriptor, "t_exec_time_ck: %0d\n",              experimental_stats.t_exec_time_ck);
              // Experimental setup - Close file
              $fclose(fileDescriptor);
            end

            // Save experiment statistics to file
            if ($value$plusargs("VSIM_LOG_CFG=%s", fileDir)) begin

              f_bw_stats_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];

                f_bw_monitor_display_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;
                  
                  // BW stats - Open file
                  $sformat(filePath, "%s/test%0d_statistics_cl_%0d_core_%0d.txt", fileDir, experimental_stats.id_test, cl_id, core_id);
                  // $display("Writing results to file: %s", filePath);
                  fileDescriptor = $fopen(filePath, "w"); 

                  // BW stats - Write values
                  $fwrite(fileDescriptor, "id_test: %0d\n",               experimental_stats.id_test);
                  $fwrite(fileDescriptor, "r_latency_mean: %0.2f\n",      bw_rt_cl_stats[cl_id][core_id].r_latency_mean);
                  $fwrite(fileDescriptor, "r_latency_stddev: %0.2f\n",    bw_rt_cl_stats[cl_id][core_id].r_latency_stddev);
                  $fwrite(fileDescriptor, "r_bw_mean: %0.2f\n",           bw_rt_cl_stats[cl_id][core_id].r_bw_mean);
                  $fwrite(fileDescriptor, "r_bw_stddev: %0.2f\n",         bw_rt_cl_stats[cl_id][core_id].r_bw_stddev);
                  $fwrite(fileDescriptor, "r_util_mean: %0.2f\n",         bw_rt_cl_stats[cl_id][core_id].r_util_mean);
                  $fwrite(fileDescriptor, "r_util_stddev: %0.2f\n",       bw_rt_cl_stats[cl_id][core_id].r_util_stddev);
                  $fwrite(fileDescriptor, "w_latency_mean: %0.2f\n",      bw_rt_cl_stats[cl_id][core_id].w_latency_mean);
                  $fwrite(fileDescriptor, "w_latency_stddev: %0.2f\n",    bw_rt_cl_stats[cl_id][core_id].w_latency_stddev);
                  $fwrite(fileDescriptor, "w_bw_mean: %0.2f\n",           bw_rt_cl_stats[cl_id][core_id].w_bw_mean);
                  $fwrite(fileDescriptor, "w_bw_stddev: %0.2f\n",         bw_rt_cl_stats[cl_id][core_id].w_bw_stddev);
                  $fwrite(fileDescriptor, "w_util_mean: %0.2f\n",         bw_rt_cl_stats[cl_id][core_id].w_util_mean);
                  $fwrite(fileDescriptor, "w_util_stddev: %0.2f\n",       bw_rt_cl_stats[cl_id][core_id].w_util_stddev);

                  // BW stats - Close file
                  $fclose(fileDescriptor);
                end
              end
            end

            // Save burst timestamps to file
            if ($value$plusargs("VSIM_LOG_CFG=%s", fileDir)) begin
              f_latency_loop_0: for (int i = 0; i < NumClustersActive; i++) begin
                automatic int cl_id = IdTestCl[i];

                f_latency_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
                  automatic int core_id = j;

                  // Latency - Open file
                  $sformat(filePath, "%s/test%0d_burst_stats_cl_%0d_core_%0d.txt", fileDir, experimental_stats.id_test, cl_id, core_id);
                  // $display("Writing results to file: %s", filePath);
                  fileDescriptor = $fopen(filePath, "w"); 

                  // Latency - Write header
                  $fwrite(fileDescriptor, "iter, t0, t1, lat, bw, n_beats, dw_bit\n");

                  // Latency - Write values
                  foreach (bw_rt_cl_stats[cl_id][core_id].r_burst_t0[i]) begin
                    $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
                      i,
                      bw_rt_cl_stats[cl_id][core_id].r_burst_t0[i], 
                      bw_rt_cl_stats[cl_id][core_id].r_burst_t1[i], 
                      bw_rt_cl_stats[cl_id][core_id].r_latency_val[i], 
                      bw_rt_cl_stats[cl_id][core_id].r_bw_val[i], 
                      bw_rt_cl_stats[cl_id][core_id].r_burst_n_beats[i], 
                      bw_rt_cl_stats[cl_id][core_id].r_burst_dw[i]
                    );
                  end

                  // Latency - Close file
                  $fclose(fileDescriptor);
                end
              end
            end

            NTest = NTest + 1;
            tb_timer_cnt_value_old = tb_timer_cnt_value; // Store old counter value

            @(posedge `CLK_SIGNAL);
          end // burst_length_loop
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

