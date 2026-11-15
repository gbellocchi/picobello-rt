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
`define TRACE_NOC_LINKS // per-packet wide-plane link trace (golden reference for runs/py_model_bw)
`define PROBE_AXI_REALM // per-period AXI-REALM admission/charge log of every wide-plane unit

// Traffic flow setup. With FLOOMODEL_GOLDEN the scenario define comes from the command line
// (floomodel rtl/picobello-rt/tools/run_manifest.py: bender -D INTER_FLOW_<h>H or -D FLOOMODEL_FLOWS).
`ifndef FLOOMODEL_GOLDEN
// `define INTRA_FLOW_1H_ENDPOINT
// `define INTER_FLOW_1H_ENDPOINT  
// `define INTER_FLOW_1H
`define INTER_FLOW_2H
// `define INTER_FLOW_4H
// `define INTER_FLOW_8H
// `define INTER_HOST_CTRL_PLANE_DIRECT_INTERF
`endif

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

  // Interferer reconfiguration after critical task termination
  localparam bit RuntimeInterfReconfig = 1'b0;
  int InterfBurstLengthReconfig = 32'd256; // max allowed by axi4

  // Traffic dimension (hardwired in traffic generator design)
  int TrafficDim = 256 * 128;

  // Set order and time displacement between critical and interferer groups.
  // -- CriticalFirst=1: critical clusters start first; 0: interferers start first.
  // -- InterGroupDelay: clock cycles inserted between the first and second group launch.
  localparam bit          CriticalFirst       = 1'b1;
  localparam int unsigned InterGroupDelay     = 0;

  // Worst-case scenario for the unfair critical task IdTestCl[0]: the interconnect is loaded for its
  // whole activity.
  // -- Interferers start first and run alone for WorstCaseWarmup clock cycles to fill the NoC, then
  //    critical tasks start (CriticalFirst and InterGroupDelay are ignored). The warmup must be
  //    shorter than one interferer job: DMAs found idle after it are treated as having no job.
  // -- Every interferer DMA that terminates its job is relaunched with the same job until
  //    IdTestCl[0] terminates, so interferers never run out of traffic. With WorstCaseFairBacklog,
  //    the other critical tasks are relaunched too, so the memory port stays shared by four.
  // -- CriticalExecTime is the execution time of IdTestCl[0]. With WorstCaseTimeout != 0 the test
  //    stops waiting for it after that many clock cycles (InterfRelaunches/Timeout report it).
  // -- Afterwards the interferer IMTU is disabled, so their last job drains without regulation.
  bit          WorstCaseScenario    = 1'b0; // +WC=0|1
  localparam int unsigned WorstCaseWarmup      = 4096;
  localparam bit          WorstCaseFairBacklog = 1'b1;
  int unsigned WorstCaseTimeout     = 0;    // +WC_TIMEOUT=<cycles>
  bit          LaunchCriticalFirst;         // set after the plusargs
  int unsigned LaunchGroupDelay;            // set after the plusargs

  // Worst-case scenario state
  bit          wc_critical_done;    // IdTestCl[0] terminated (or timed out), stop relaunching
  bit          wc_critical_timeout; // IdTestCl[0] did not terminate within WorstCaseTimeout
  int          wc_relaunch_active;  // relaunch threads still running
  int unsigned wc_relaunch_cnt;     // jobs relaunched while IdTestCl[0] was active

  // AXI-Realm features
  bit CriticalBudgetPeriodActive   = 1'b1; // +REG_C=0|1
  int unsigned realm_cfg_gap = 0; // +REALM_CFG_GAP=<cycles> after each IMTU enable (period phase studies)
  bit InterfBudgetPeriodActive     = 1'b1; // +REG_I=0|1

  // Critical fragment length coupled to the budget: each test uses the largest fragment that fits
  // in the budget, min(CriticalBurstLength, CriticalBudget / bytes per beat).
  localparam bit CriticalFragmFitBudget       = 1'b0;
  localparam int unsigned CriticalBytesPerBeat = fpga_picobello_pkg::AxiCfgW.DataWidth / 8;

  // Linear mapping: CriticalBudget is the target number of bytes per period. The IMTU admits one
  // uncharged fragment per period when the next request is already pending as the budget runs out,
  // so the programmed budget is reduced by that fragment and the fragment length is chosen to keep
  // the result exact. CriticalOvershootUnfragm: 1 if this also happens with unsplit
  // CriticalBurstLength bursts (reads), 0 otherwise (writes).
  localparam bit CriticalFragmLinear          = 1'b0;
  localparam bit CriticalOvershootUnfragm     = 1'b0;

  // ------------------------------------------------------------- //
  // Intra-flow setup
  `ifdef INTRA_FLOW_1H_ENDPOINT
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX0Y0SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd1; // no fragmentation (max allowed by axi4)
    int CriticalBurstLengthMax = 32'd1; // max allowed by axi4

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd16;   // 4 kB = 1 burst per period @FL-BE=256Beats
    int CriticalBudgetMax = 32'd131072; // 128 kB = whole payload (32 bursts) in one period

    // Period for critical tasks
    int CriticalPeriodMin = 32'd2048; // 2048 Ck
    int CriticalPeriodMax = 32'd2048; // 2048 Ck

    // Interferer flow
    localparam int unsigned NumClustersInterf = 1;
    localparam int unsigned NumClustersInterfActive = 0;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{ClusterX0Y0SamIdx};
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd1; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd1; // max allowed by axi4

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd16384;  // 16 kB / 64
    int InterfBudgetMax = 32'd16384; // 16 kB / 1

    // Period for interferer tasks
    int InterfPeriodMin = 32'd0; // 0 Ck
    int InterfPeriodMax = 32'd0; // 0 Ck

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

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd16384; // 16 kB
    int CriticalBudgetMax = 32'd16384; // 16 kB

    // Period for critical tasks
    int CriticalPeriodMin = 32'd0; // 0 Ck
    int CriticalPeriodMax = 32'd0; // 0 Ck

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

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd16; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd16; // max allowed by axi4

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd256;  // 16 kB / 64 = 16 Beats = 1 Burst @FL-BE=16Beats
    int InterfBudgetMax = 32'd16384; // 16 kB = 64 bursts @FL-BE=16Beats

    // Period for interferer tasks
    int InterfPeriodMin = 32'd2048; // 2048 Ck = 128 burst periods @FL-BE=16Beats
    int InterfPeriodMax = 32'd2048; // 2048 Ck = 128 burst periods @FL-BE=16Beats

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 1 hop
  // Four critical tasks, one per input port of the memory router [1, 2]. The critical task on [1, 1]
  // shares the [1, 1] -> [1, 2] link with three upstream interferers (topological unfairness).
  `ifdef INTER_FLOW_1H
    // Critical flow
    localparam int unsigned NumClustersActive = 4;
    localparam int unsigned IdTestCl[NumClustersActive] = '{
      ClusterX1Y1SamIdx, // router [1, 1], shares its link with the interferers
      ClusterX0Y2SamIdx, // router [0, 2]
      ClusterX1Y2SamIdx, // router [1, 3]
      ClusterX2Y2SamIdx  // router [2, 2]
    };
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd16; // 256-beat bursts split into 32-beat fragments
    int CriticalBurstLengthMax = 32'd16; // 256-beat bursts split into 32-beat fragments

    // Budget for critical tasks
    // Same period as the interferers, max credit for that period (period x 16 B)
    int CriticalBudgetMin = 32'd131072; // max credit for the period (65536 Ck x 16 B)
    int CriticalBudgetMax = 32'd131072; // max credit for the period (65536 Ck x 16 B)

    // Period for critical tasks
    int CriticalPeriodMin = 32'd8192; // 65536 Ck, same as the interferers
    int CriticalPeriodMax = 32'd8192; // 65536 Ck, same as the interferers

    // Interferer flow
    localparam int unsigned NumClustersInterf = 3;
    localparam int unsigned NumClustersInterfActive = 3;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX1Y0SamIdx, // router [1, 0]
      ClusterX0Y1SamIdx, // router [0, 1]
      ClusterX2Y1SamIdx  // router [2, 1]
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd16; // 256-beat bursts split into 32-beat fragments
    int InterfBurstLengthMax = 32'd16; // 256-beat bursts split into 32-beat fragments

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd256; // 512 B = 1 fragment per period @FL-BE=32Beats
    int InterfBudgetMax = 32'd256; // 512 B = 1 fragment per period @FL-BE=32Beats

    // Period for interferer tasks
    // Longer periods lower the period utilization at a fixed fragment length
    int InterfPeriodMin = 32'd8192; // 65536 Ck = 0.05% utilization @512 B
    int InterfPeriodMax = 32'd8192; // 65536 Ck = 0.05% utilization @512 B

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 2 hops
  // Four critical tasks write to the memory tile at router [1, 3]. Three of them sit one hop
  // from it, one per input port. The critical task on [1, 1] is 2 hops away and shares every
  // link of its path with three local interferers (topological unfairness).
  `ifdef INTER_FLOW_2H
    // Critical flow
    localparam int unsigned NumClustersActive = 4;
    localparam int unsigned IdTestCl[NumClustersActive] = '{
      ClusterX1Y1SamIdx, // router [1, 1], shares its path with the interferers
      ClusterX0Y3SamIdx, // router [0, 3]
      ClusterX1Y3SamIdx, // router [1, 4]
      ClusterX2Y3SamIdx  // router [2, 3]
    };
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd16; // fragment length, same as the interferers
    int CriticalBurstLengthMax = 32'd16; // fragment length, same as the interferers

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd131072; // max credit for the period (period x 16 B)
    int CriticalBudgetMax = 32'd131072; // max credit for the period (period x 16 B)

    // Period for critical tasks
    int CriticalPeriodMin = 32'd8192; // same as the interferers
    int CriticalPeriodMax = 32'd8192; // same as the interferers

    // Interferer flow
    localparam int unsigned NumClustersInterf = 6;
    localparam int unsigned NumClustersInterfActive = 6;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX1Y0SamIdx, // hop 1, ejects at [1, 2]
      ClusterX0Y1SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX0Y2SamIdx, // hop 2, ejects at the memory tile
      ClusterX1Y2SamIdx,
      ClusterX2Y2SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx,
      L2Spm0SamIdx
    }; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd16; // fragment length
    int InterfBurstLengthMax = 32'd16; // fragment length

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd256; // credit floor = 1 fragment per period (fragment length x 16 B)
    int InterfBudgetMax = 32'd256; // credit floor = 1 fragment per period (fragment length x 16 B)

    // Period for interferer tasks
    int InterfPeriodMin = 32'd8192; // same as the critical tasks
    int InterfPeriodMax = 32'd8192; // same as the critical tasks

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 4 hops
  // Four critical tasks write to the memory tile at router [1, 5]. Three of them sit one hop
  // from it, one per input port. The critical task on [1, 1] is 4 hops away and shares every
  // link of its path with three local interferers (topological unfairness).
  `ifdef INTER_FLOW_4H
    // Critical flow
    localparam int unsigned NumClustersActive = 4;
    localparam int unsigned IdTestCl[NumClustersActive] = '{
      ClusterX1Y1SamIdx, // router [1, 1], shares its path with the interferers
      ClusterX0Y5SamIdx, // router [0, 5]
      ClusterX1Y5SamIdx, // router [1, 6]
      ClusterX2Y5SamIdx  // router [2, 5]
    };
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd32; // fragment length, same as the interferers
    int CriticalBurstLengthMax = 32'd32; // fragment length, same as the interferers

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd32768; // max credit for the period (period x 16 B)
    int CriticalBudgetMax = 32'd32768; // max credit for the period (period x 16 B)

    // Period for critical tasks
    int CriticalPeriodMin = 32'd2048; // same as the interferers
    int CriticalPeriodMax = 32'd2048; // same as the interferers

    // Interferer flow
    localparam int unsigned NumClustersInterf = 12;
    localparam int unsigned NumClustersInterfActive = 12;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX1Y0SamIdx, // hop 1, ejects at [1, 2]
      ClusterX0Y1SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX0Y2SamIdx, // hop 2, ejects at [1, 3]
      ClusterX1Y2SamIdx,
      ClusterX2Y2SamIdx,
      ClusterX0Y3SamIdx, // hop 3, ejects at [1, 4]
      ClusterX1Y3SamIdx,
      ClusterX2Y3SamIdx,
      ClusterX0Y4SamIdx, // hop 4, ejects at the memory tile
      ClusterX1Y4SamIdx,
      ClusterX2Y4SamIdx
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
      L2Spm0SamIdx
    }; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd32; // fragment length
    int InterfBurstLengthMax = 32'd32; // fragment length

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd512; // credit floor = 1 fragment per period (fragment length x 16 B)
    int InterfBudgetMax = 32'd512; // credit floor = 1 fragment per period (fragment length x 16 B)

    // Period for interferer tasks
    int InterfPeriodMin = 32'd2048; // same as the critical tasks
    int InterfPeriodMax = 32'd2048; // same as the critical tasks

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - 8 hops
  // Four critical tasks write to the memory tile at router [1, 9]. Three of them sit one hop
  // from it, one per input port. The critical task on [1, 1] is 8 hops away and shares every
  // link of its path with three local interferers (topological unfairness).
  `ifdef INTER_FLOW_8H
    // Critical flow
    localparam int unsigned NumClustersActive = 4;
    localparam int unsigned IdTestCl[NumClustersActive] = '{
      ClusterX1Y1SamIdx, // router [1, 1], shares its path with the interferers
      ClusterX0Y9SamIdx, // router [0, 9]
      ClusterX1Y9SamIdx, // router [1, 10]
      ClusterX2Y9SamIdx  // router [2, 9]
    };
    localparam int unsigned IdTestMem = '{L2Spm0SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd32; // fragment length, same as the interferers
    int CriticalBurstLengthMax = 32'd32; // fragment length, same as the interferers

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd32768; // max credit for the period (period x 16 B)
    int CriticalBudgetMax = 32'd32768; // max credit for the period (period x 16 B)

    // Period for critical tasks
    int CriticalPeriodMin = 32'd2048; // same as the interferers
    int CriticalPeriodMax = 32'd2048; // same as the interferers

    // Interferer flow
    localparam int unsigned NumClustersInterf = 24;
    localparam int unsigned NumClustersInterfActive = 24;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX1Y0SamIdx, // hop 1, ejects at [1, 2]
      ClusterX0Y1SamIdx,
      ClusterX2Y1SamIdx,
      ClusterX0Y2SamIdx, // hop 2, ejects at [1, 3]
      ClusterX1Y2SamIdx,
      ClusterX2Y2SamIdx,
      ClusterX0Y3SamIdx, // hop 3, ejects at [1, 4]
      ClusterX1Y3SamIdx,
      ClusterX2Y3SamIdx,
      ClusterX0Y4SamIdx, // hop 4, ejects at [1, 5]
      ClusterX1Y4SamIdx,
      ClusterX2Y4SamIdx,
      ClusterX0Y5SamIdx, // hop 5, ejects at [1, 6]
      ClusterX1Y5SamIdx,
      ClusterX2Y5SamIdx,
      ClusterX0Y6SamIdx, // hop 6, ejects at [1, 7]
      ClusterX1Y6SamIdx,
      ClusterX2Y6SamIdx,
      ClusterX0Y7SamIdx, // hop 7, ejects at [1, 8]
      ClusterX1Y7SamIdx,
      ClusterX2Y7SamIdx,
      ClusterX0Y8SamIdx, // hop 8, ejects at the memory tile
      ClusterX1Y8SamIdx,
      ClusterX2Y8SamIdx
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
      L2Spm0SamIdx
    }; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd32; // fragment length
    int InterfBurstLengthMax = 32'd32; // fragment length

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd512; // credit floor = 1 fragment per period (fragment length x 16 B)
    int InterfBudgetMax = 32'd512; // credit floor = 1 fragment per period (fragment length x 16 B)

    // Period for interferer tasks
    int InterfPeriodMin = 32'd2048; // same as the critical tasks
    int InterfPeriodMax = 32'd2048; // same as the critical tasks

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //
  // Inter-flow setup - Host control plane
  // Flow list exported by `floomodel export picobello` (critical and interferer clusters, sweep
  // bounds per role); the matching traffic file gives the DMA jobs.
  `ifdef FLOOMODEL_FLOWS
    `include "floomodel_flows.svh"
  `endif

  `ifdef INTER_HOST_CTRL_PLANE_DIRECT_INTERF
    // Critical flow
    localparam int unsigned NumClustersActive = 1;
    localparam int unsigned IdTestCl[NumClustersActive] = '{ClusterX1Y0SamIdx};
    localparam int unsigned IdTestMem = '{L2Spm1SamIdx}; // currently not used with floo dma

    // Burst length for critical tasks
    int CriticalBurstLengthMin = 32'd256; // burstless (single-beat)
    int CriticalBurstLengthMax = 32'd256; // max allowed by axi4

    // Budget for critical tasks
    int CriticalBudgetMin = 32'd16384; // 16 kB
    int CriticalBudgetMax = 32'd16384; // 16 kB

    // Period for critical tasks
    int CriticalPeriodMin = 32'd0; // 0 Ck
    int CriticalPeriodMax = 32'd0; // 0 Ck

    // Interferer flow
    localparam int unsigned NumClustersInterf = 5;
    localparam int unsigned NumClustersInterfActive = 5;
    localparam int unsigned IdTestClInterf[NumClustersInterf] = '{
      ClusterX0Y0SamIdx,
      ClusterX0Y1SamIdx,
      ClusterX1Y1SamIdx,
      ClusterX2Y0SamIdx,
      ClusterX2Y1SamIdx
    };
    localparam int unsigned IdTestMemInterf[NumClustersInterf] = '{
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx, 
      L2Spm0SamIdx
    }; // currently not used with floo dma

    // Burst length for interferer tasks
    int InterfBurstLengthMin = 32'd16; // burstless (single-beat)
    int InterfBurstLengthMax = 32'd16; // max allowed by axi4

    // Budget for interferer tasks
    int InterfBudgetMin = 32'd256;  // 16 kB / 64 = 16 Beats = 1 Burst @FL-BE=16Beats
    int InterfBudgetMax = 32'd256; // 32'd16384; // 16 kB = 64 bursts @FL-BE=16Beats

    // Period for interferer tasks
    int InterfPeriodMin = 32'd2048; // 2048 Ck = 128 burst periods @FL-BE=16Beats
    int InterfPeriodMax = 32'd2048; // 2048 Ck = 128 burst periods @FL-BE=16Beats

    // Number of DMAs
    localparam int unsigned NumCoresActive = 1;
  `endif
  // ------------------------------------------------------------- //

  ///////////////////////////////
  // TB exploration variables  //
  ///////////////////////////////

  // Number of performed tests
  int NTest = 0;

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

  ////////////////////
  // NoC link trace //
  ////////////////////

`ifdef TRACE_NOC_LINKS
  `include "tb_noc_link_tracer.svh"
`endif
`ifdef PROBE_AXI_REALM
  `include "tb_axi_realm_probe.svh"
`endif

  //////////////////
  // floomodel golden runs: sweep bounds and switches from plusargs, so one compiled library per
  // topology serves every configuration (rtl/picobello-rt/tools/run_manifest.py). Each plusarg
  // sets Min and Max of its sweep: +FL_C +BUDGET_C +PERIOD_C +FL_I +BUDGET_I +PERIOD_I, and
  // +WC +WC_TIMEOUT +REG_C +REG_I. Without plusargs the values above apply.
  task automatic floomodel_plusargs();
    int v;
    if ($value$plusargs("FL_C=%d", v))     begin CriticalBurstLengthMin = v; CriticalBurstLengthMax = v; end
    if ($value$plusargs("BUDGET_C=%d", v)) begin CriticalBudgetMin = v;      CriticalBudgetMax = v;      end
    if ($value$plusargs("PERIOD_C=%d", v)) begin CriticalPeriodMin = v;      CriticalPeriodMax = v;      end
    if ($value$plusargs("FL_I=%d", v))     begin InterfBurstLengthMin = v;   InterfBurstLengthMax = v;   end
    if ($value$plusargs("BUDGET_I=%d", v)) begin InterfBudgetMin = v;        InterfBudgetMax = v;        end
    if ($value$plusargs("PERIOD_I=%d", v)) begin InterfPeriodMin = v;        InterfPeriodMax = v;        end
    if ($value$plusargs("WC=%d", v))         WorstCaseScenario = v[0];
    if ($value$plusargs("WC_TIMEOUT=%d", v)) WorstCaseTimeout = v;
    if ($value$plusargs("REG_C=%d", v))      CriticalBudgetPeriodActive = v[0];
    if ($value$plusargs("REG_I=%d", v))      InterfBudgetPeriodActive = v[0];
    if ($value$plusargs("REALM_CFG_GAP=%d", v)) realm_cfg_gap = v;
    LaunchCriticalFirst = WorstCaseScenario ? 1'b0 : CriticalFirst;
    LaunchGroupDelay    = WorstCaseScenario ? WorstCaseWarmup : InterGroupDelay;
  endtask

  // TB execution //
  //////////////////

  initial begin
    floomodel_plusargs();
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

            	// Loop over budget values of critical tasks (geometric progression)
            	critical_task_budget_loop: for (int CriticalBudget = CriticalBudgetMin; CriticalBudget <= CriticalBudgetMax; CriticalBudget = (CriticalBudget == 0) ? 1 : CriticalBudget * 2) begin

            	  // Fragment length applied to critical tasks
            	  automatic int CriticalFragmLength = CriticalBurstLength;
            	  // Budget programmed in AXI-Realm
            	  automatic int CriticalBudgetProg = CriticalBudget;
            	  automatic int CriticalBurstBytes = CriticalBurstLength * CriticalBytesPerBeat;
            	  if (CriticalFragmFitBudget && (CriticalBudget / CriticalBytesPerBeat < CriticalBurstLength)) begin
            	    CriticalFragmLength = (CriticalBudget < CriticalBytesPerBeat) ? 1 : CriticalBudget / CriticalBytesPerBeat;
            	  end
            	  if (CriticalFragmLinear) begin
            	    if ((CriticalBudget >= 2 * CriticalBurstBytes) ||
            	        (!CriticalOvershootUnfragm && (CriticalBudget % CriticalBurstBytes == 0))) begin
            	      // Unsplit bursts, budget reduced by the uncharged burst (if any)
            	      CriticalFragmLength = CriticalBurstLength;
            	      CriticalBudgetProg  = CriticalBudget - (CriticalOvershootUnfragm ? CriticalBurstBytes : 0);
            	    end else begin
            	      // Two fragments per period: one charged, one uncharged
            	      CriticalFragmLength = CriticalBudget / (2 * CriticalBytesPerBeat);
            	      CriticalBudgetProg  = CriticalBudget / 2;
            	    end
            	  end

            		// Loop over period values of critical tasks (geometric progression)
            		critical_task_period_loop: for (int CriticalPeriod = CriticalPeriodMin; CriticalPeriod <= CriticalPeriodMax; CriticalPeriod = (CriticalPeriod == 0) ? 1 : CriticalPeriod * 2) begin

            			// Loop over budget values of interferer tasks (geometric progression)
            			interferer_task_budget_loop: for (int InterfBudget = InterfBudgetMin; InterfBudget <= InterfBudgetMax; InterfBudget = (InterfBudget == 0) ? 1 : InterfBudget * 2) begin

            				// Loop over period values of interferer tasks (geometric progression)
            				interferer_task_period_loop: for (int InterfPeriod = InterfPeriodMin; InterfPeriod <= InterfPeriodMax; InterfPeriod = (InterfPeriod == 0) ? 1 : InterfPeriod * 2) begin

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
				                tb_rt_cfg.rt_regfile_cfg.read_budget[tb_rt_cfg.sbr_addr_reg_id]         = CriticalBudgetProg;
				                // Set the write budget (32b)
				                tb_rt_cfg.rt_regfile_cfg.write_budget[tb_rt_cfg.sbr_addr_reg_id]        = CriticalBudgetProg;

				                // Set the read period (32b)
				                tb_rt_cfg.rt_regfile_cfg.read_period[tb_rt_cfg.sbr_addr_reg_id]         = CriticalPeriod;
				                // Set the write period (32b)
				                tb_rt_cfg.rt_regfile_cfg.write_period[tb_rt_cfg.sbr_addr_reg_id]        = CriticalPeriod;

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

				                // Flush AXI-Realm period-budget counters, so that each test starts with a new period and a full budget
				                if(CriticalBudgetPeriodActive) begin
				                  picobello_rt_flush_imtu(tb_rt_cfg);
				                end

				                // Configure AXI-Realm period-budget QoS service
				                picobello_rt_set_period_budget(tb_rt_cfg);

				                // Set and configure AXI-Realm manager registers
				                rt_cfg_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
				                  automatic int core_id = j;

				                  // Set manager ID
				                  tb_rt_cfg.mgr_id                                                    = core_id;

				                  // Set the burst length limit (8b)
				                  tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mgr_id]                = (CriticalFragmLength - 1) & 8'hFF;

				                  // Set IMTU abort (1b)
				                  tb_rt_cfg.rt_regfile_cfg.imtu_abort[tb_rt_cfg.mgr_id]               = '0;

				                  // Set IMTU enable (1b)
				                  tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id]              = CriticalBudgetPeriodActive;

				                  // Enable real-time mode (1b)
				                  tb_rt_cfg.rt_regfile_cfg.rt_enable[tb_rt_cfg.mgr_id]                = '1;

				                  // Activate AXI-Realm

				                  // Set burst length
				                  picobello_rt_set_burst_length(tb_rt_cfg);

                          // Enable IMTU
                          if(CriticalBudgetPeriodActive) begin
				                    picobello_rt_abort_imtu(tb_rt_cfg);
				                    picobello_rt_enable_imtu(tb_rt_cfg);
                    if (realm_cfg_gap != 0) `wait_n_clk(realm_cfg_gap); // +REALM_CFG_GAP: shifts the period phases
                          end

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
				                tb_rt_cfg.rt_regfile_cfg.read_budget[tb_rt_cfg.sbr_addr_reg_id]         = InterfBudget;
				                // Set the write budget (32b)
				                tb_rt_cfg.rt_regfile_cfg.write_budget[tb_rt_cfg.sbr_addr_reg_id]        = InterfBudget;

				                // Set the read period (32b)
				                tb_rt_cfg.rt_regfile_cfg.read_period[tb_rt_cfg.sbr_addr_reg_id]         = InterfPeriod;
				                // Set the write period (32b)
				                tb_rt_cfg.rt_regfile_cfg.write_period[tb_rt_cfg.sbr_addr_reg_id]        = InterfPeriod;

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

				                // Flush AXI-Realm period-budget counters, so that each test starts with a new period and a full budget
				                if(InterfBudgetPeriodActive) begin
				                  picobello_rt_flush_imtu(tb_rt_cfg);
				                end

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
				                  tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id]              = InterfBudgetPeriodActive;

				                  // Enable real-time mode (1b)
				                  tb_rt_cfg.rt_regfile_cfg.rt_enable[tb_rt_cfg.mgr_id]                = '1;

				                  // Set burst length
				                  picobello_rt_set_burst_length(tb_rt_cfg);

                          // Enable IMTU
                          if(InterfBudgetPeriodActive) begin
				                    picobello_rt_abort_imtu(tb_rt_cfg);
				                    picobello_rt_enable_imtu(tb_rt_cfg);
                    if (realm_cfg_gap != 0) `wait_n_clk(realm_cfg_gap); // +REALM_CFG_GAP: shifts the period phases
                          end

				                  // Enable real-time mode
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
				                for (int j = 0; j < NumCoresActive; j++) picobello_reset_bw_monitor_2d(bw_rt_cl_cfg, cl_id, j); // before AXI-REALM
				              end

				              // Initialize BW monitor for interferers
				              bw_interf_monitor_init_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
				                automatic int cl_id = IdTestClInterf[i];
				                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                picobello_reset_bw_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                for (int j = 0; j < NumCoresActive; j++) picobello_reset_bw_monitor_2d(bw_rt_cl_cfg, cl_id, j); // before AXI-REALM
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

				              // Store total start time
				              t_total.t0 = tb_timer_cnt_value;
`ifdef TRACE_NOC_LINKS
				              noc_trace_test     = NTest;
				              noc_trace_t0_timer = tb_timer_cnt_value;
				              noc_trace_en       = 1'b1;
`endif
`ifdef PROBE_AXI_REALM
				              realm_probe_test = NTest;
				              realm_probe_en   = 1'b1;
`endif

				              // DMA: launch first group (critical if LaunchCriticalFirst, else interferer)
				              if (LaunchCriticalFirst) t_critical.t0   = tb_timer_cnt_value;
				              else               t_interferer.t0 = tb_timer_cnt_value;

				              dma_in_start_first_loop_0: for (int i = 0; i < (LaunchCriticalFirst ? NumClustersActive : NumClustersInterfActive); i++) begin
				                automatic int cl_id = LaunchCriticalFirst ? IdTestCl[i] : IdTestClInterf[i];

				                if(DmaReadEnable) begin
				                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_start_bw_r_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end
				                if(DmaWriteEnable) begin
				                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_start_bw_w_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end

				                dma_in_start_first_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
				                  automatic int core_id = j;
				                  for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
				                    if(DmaReadEnable) dpi_rt.dma_read_start_high(cl_id, core_id, noc_plane_id);
				                    if(DmaWriteEnable) dpi_rt.dma_write_start_high(cl_id, core_id, noc_plane_id);
				                  end
				                end
				                dma_r_timer_0[cl_id] = tb_timer_cnt_value;
				              end

				              // Inter-group displacement
				              `wait_n_clk(LaunchGroupDelay);

				              // DMA: launch second group (interferer if LaunchCriticalFirst, else critical)
				              if (LaunchCriticalFirst) t_interferer.t0 = tb_timer_cnt_value;
				              else               t_critical.t0   = tb_timer_cnt_value;

				              dma_in_start_second_loop_0: for (int i = 0; i < (LaunchCriticalFirst ? NumClustersInterfActive : NumClustersActive); i++) begin
				                automatic int cl_id = LaunchCriticalFirst ? IdTestClInterf[i] : IdTestCl[i];

				                if(DmaReadEnable) begin
				                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_start_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_start_bw_r_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end
				                if(DmaWriteEnable) begin
				                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_start_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_start_bw_w_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end

				                dma_in_start_second_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
				                  automatic int core_id = j;
				                  for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
				                    if(DmaReadEnable) dpi_rt.dma_read_start_high(cl_id, core_id, noc_plane_id);
				                    if(DmaWriteEnable) dpi_rt.dma_write_start_high(cl_id, core_id, noc_plane_id);
				                  end
				                end
				                dma_r_timer_0[cl_id] = tb_timer_cnt_value;
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

				              // Worst case: relaunch every DMA that terminates while the unfair critical task
				              // IdTestCl[0] runs: the interferers and, with WorstCaseFairBacklog, the other critical tasks
				              wc_critical_done    = 1'b0;
				              wc_critical_timeout = 1'b0;
				              wc_relaunch_active  = 0;
				              wc_relaunch_cnt     = 0;
				              if (WorstCaseScenario) begin
				                wc_relaunch_loop_0: for (int i = 0; i < NumClustersInterfActive + NumClustersActive - 1; i++) begin
				                  wc_relaunch_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
				                    for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
				                      automatic int cl_id    = (i < NumClustersInterfActive) ? IdTestClInterf[i] :
				                                               IdTestCl[i - NumClustersInterfActive + 1];
				                      automatic int core_id  = j;
				                      automatic int plane_id = noc_plane_id;

				                      if (i >= NumClustersInterfActive && !WorstCaseFairBacklog) continue;

				                      // Same idle flag polled by dma_*_wait_idle. DMAs already idle after the
				                      // warmup have no job (e.g. the narrow plane) and are not relaunched.
				                      if ((DmaWriteEnable ?
				                           dpi_rt.dma_write_get_idle(cl_id, core_id, plane_id, fpga_picobello_pkg::UseHlsTg) :
				                           dpi_rt.dma_read_get_idle(cl_id, core_id, plane_id, fpga_picobello_pkg::UseHlsTg)) == 1) begin
				                        continue;
				                      end

				                      wc_relaunch_active++;
				                      fork
				                        begin
				                          while (!wc_critical_done) begin
				                            if ((DmaWriteEnable ?
				                                 dpi_rt.dma_write_get_idle(cl_id, core_id, plane_id, fpga_picobello_pkg::UseHlsTg) :
				                                 dpi_rt.dma_read_get_idle(cl_id, core_id, plane_id, fpga_picobello_pkg::UseHlsTg)) == 1) begin
				                              wc_relaunch_cnt++;
				                              if(DmaReadEnable) dpi_rt.dma_read_start_high(cl_id, core_id, plane_id);
				                              if(DmaWriteEnable) dpi_rt.dma_write_start_high(cl_id, core_id, plane_id);
				                              `wait_n_clk(1);
				                              if(DmaReadEnable) dpi_rt.dma_read_start_low(cl_id, core_id, plane_id);
				                              if(DmaWriteEnable) dpi_rt.dma_write_start_low(cl_id, core_id, plane_id);
				                              // Let the DMA leave idle before polling again
				                              `wait_n_clk(5);
				                            end else begin
				                              `wait_n_clk(1);
				                            end
				                          end
				                          wc_relaunch_active--;
				                        end
				                      join_none
				                    end
				                  end
				                end
				              end

				              // Worst case: wait for the unfair critical task only (or WorstCaseTimeout cycles), then
				              // stop relaunching and let the last jobs drain, the interferers without regulation
				              if (WorstCaseScenario) begin
				                automatic int unsigned wc_cycles = 0;
				                automatic bit          wc_idle   = 1'b0;

				                while (!wc_idle) begin
				                  wc_idle = 1'b1;
				                  for (int j = 0; j < NumCoresActive; j++) begin
				                    for (int noc_plane_id = 0; noc_plane_id < NumNoCPlanes; noc_plane_id++) begin
				                      wc_idle &= ((DmaWriteEnable ?
				                                   dpi_rt.dma_write_get_idle(IdTestCl[0], j, noc_plane_id, fpga_picobello_pkg::UseHlsTg) :
				                                   dpi_rt.dma_read_get_idle(IdTestCl[0], j, noc_plane_id, fpga_picobello_pkg::UseHlsTg)) == 1);
				                    end
				                  end
				                  if (!wc_idle) begin
				                    if (WorstCaseTimeout != 0 && wc_cycles >= WorstCaseTimeout) begin
				                      wc_critical_timeout = 1'b1;
				                      break;
				                    end
				                    `wait_n_clk(1);
				                    wc_cycles++;
				                  end
				                end

				                dma_r_timer_1[IdTestCl[0]]   = tb_timer_cnt_value;
				                dma_r_timer_val[IdTestCl[0]] = dma_r_timer_1[IdTestCl[0]] - dma_r_timer_0[IdTestCl[0]];
				                t_critical.t1                = tb_timer_cnt_value;

				                wc_critical_done = 1'b1;
				                wait (wc_relaunch_active == 0);

				                if (InterfBudgetPeriodActive) begin
				                  rt_interf_wc_drain_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
				                    automatic int cl_id = IdTestClInterf[i];

				                    tb_rt_cfg.rt_reg_addr_offset = cluster_rt_addr_offset;
				                    tb_rt_cfg.rt_reg_addr_base   = Sam[cl_id + ClusterX0Y0SamIdx].start_addr + tb_rt_cfg.rt_reg_addr_offset;

				                    rt_interf_wc_drain_loop_1: for (int j = 0; j < NumCoresActive; j++) begin
				                      tb_rt_cfg.mgr_id                                       = j;
				                      tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id] = 1'b0;
				                      picobello_rt_enable_imtu(tb_rt_cfg);
                    if (realm_cfg_gap != 0) `wait_n_clk(realm_cfg_gap); // +REALM_CFG_GAP: shifts the period phases
				                    end
				                  end
				                end
				              end

				              // DMA: wait for completion (critical tasks only; worst case: the remaining ones)
				              dma_in_idle_loop_0: for (int i = (WorstCaseScenario ? 1 : 0); i < NumClustersActive; i++) begin
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

				              // Store timer value for critical tasks (worst case: the unfair one, stored above)
				              if (!WorstCaseScenario) t_critical.t1 = tb_timer_cnt_value;

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
				                  for (int j = 0; j < NumCoresActive; j++) picobello_stop_bw_r_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end
				                if(DmaWriteEnable) begin
				                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_stop_bw_w_monitor_2d(bw_rt_cl_cfg, cl_id, j);
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
`ifdef TRACE_NOC_LINKS
				              noc_trace_en = 1'b0;
`endif
`ifdef PROBE_AXI_REALM
				              realm_probe_en = 1'b0;
`endif

				              // Stop BW monitors for interferer tasks
				              interferer_task_stop_bw_monitors_loop_0: for (int i = 0; i < NumClustersInterfActive; i++) begin
				                automatic int cl_id = IdTestClInterf[i];
				                if(DmaReadEnable) begin
				                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_stop_bw_r_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_stop_bw_r_monitor_2d(bw_rt_cl_cfg, cl_id, j);
				                end
				                if(DmaWriteEnable) begin
				                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_wide_cfg, cl_id);
				                  picobello_stop_bw_w_monitor_1d(bw_rt_noc_ni_narrow_cfg, cl_id);
				                  for (int j = 0; j < NumCoresActive; j++) picobello_stop_bw_w_monitor_2d(bw_rt_cl_cfg, cl_id, j);
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
				              $display (" - Realm -- CriticalBurstLength:   %8d", CriticalFragmLength);
				              $display (" - Realm -- InterfBurstLength:     %8d", InterfBurstLength);
				              $display (" - Realm -- CriticalBudget:        %8d", CriticalBudget);
				              $display (" - Realm -- CriticalBudgetProg:    %8d", CriticalBudgetProg);
				              $display (" - Realm -- CriticalPeriod:        %8d", CriticalPeriod);
				              $display (" - Realm -- InterfBudget:          %8d", InterfBudget);
				              $display (" - Realm -- InterfPeriod:          %8d", InterfPeriod);
				              $display (" - Results -- TotalExecTime:       %8d", experimental_stats.t_exec_time_ck[0]);
				              $display (" - Results -- CriticalExecTime:    %8d", experimental_stats.t_exec_time_ck[1]);
				              $display (" - Results -- InterfExecTime:      %8d", experimental_stats.t_exec_time_ck[2]);
				              $display (" - WorstCase -- Scenario:          %8d", WorstCaseScenario);
				              $display (" - WorstCase -- Warmup:            %8d", WorstCaseWarmup);
				              $display (" - WorstCase -- FairBacklog:       %8d", WorstCaseFairBacklog);
				              $display (" - WorstCase -- InterfRelaunches:  %8d", wc_relaunch_cnt);
				              $display (" - WorstCase -- Timeout:           %8d", wc_critical_timeout);
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
				                $fwrite(fileDescriptor, "burst_length: %0d\n",                CriticalFragmLength);
				                $fwrite(fileDescriptor, "burst_length_interf: %0d\n",         InterfBurstLength);
				                $fwrite(fileDescriptor, "budget: %0d\n",                      CriticalBudget);
				                $fwrite(fileDescriptor, "budget_prog: %0d\n",                 CriticalBudgetProg);
				                $fwrite(fileDescriptor, "period: %0d\n",                      CriticalPeriod);
				                $fwrite(fileDescriptor, "budget_interf: %0d\n",               InterfBudget);
				                $fwrite(fileDescriptor, "period_interf: %0d\n",               InterfPeriod);
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

				                  // BW stats (wide) - Open file
				                  $sformat(filePath, "%s/test%0d_noc_ni_statistics_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
				                  fileDescriptor = $fopen(filePath, "w"); 

				                  // BW stats (wide) - Write values
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

				                  // BW stats (wide) - Close file
				                  $fclose(fileDescriptor);

				                  // BW stats (narrow) - Open file
				                  $sformat(filePath, "%s/test%0d_noc_ni_narrow_statistics_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
				                  fileDescriptor = $fopen(filePath, "w"); 

				                  // BW stats (narrow) - Write values
				                  $fwrite(fileDescriptor, "id_test: %0d\n",               experimental_stats.id_test);
				                  $fwrite(fileDescriptor, "r_latency_mean: %0.2f\n",      bw_rt_noc_ni_narrow_stats[cl_id].r_latency_mean);
				                  $fwrite(fileDescriptor, "r_latency_stddev: %0.2f\n",    bw_rt_noc_ni_narrow_stats[cl_id].r_latency_stddev);
				                  $fwrite(fileDescriptor, "r_bw_mean: %0.2f\n",           bw_rt_noc_ni_narrow_stats[cl_id].r_bw_mean);
				                  $fwrite(fileDescriptor, "r_bw_stddev: %0.2f\n",         bw_rt_noc_ni_narrow_stats[cl_id].r_bw_stddev);
				                  $fwrite(fileDescriptor, "r_util_mean: %0.2f\n",         bw_rt_noc_ni_narrow_stats[cl_id].r_util_mean);
				                  $fwrite(fileDescriptor, "r_util_stddev: %0.2f\n",       bw_rt_noc_ni_narrow_stats[cl_id].r_util_stddev);
				                  $fwrite(fileDescriptor, "w_latency_mean: %0.2f\n",      bw_rt_noc_ni_narrow_stats[cl_id].w_latency_mean);
				                  $fwrite(fileDescriptor, "w_latency_stddev: %0.2f\n",    bw_rt_noc_ni_narrow_stats[cl_id].w_latency_stddev);
				                  $fwrite(fileDescriptor, "w_bw_mean: %0.2f\n",           bw_rt_noc_ni_narrow_stats[cl_id].w_bw_mean);
				                  $fwrite(fileDescriptor, "w_bw_stddev: %0.2f\n",         bw_rt_noc_ni_narrow_stats[cl_id].w_bw_stddev);
				                  $fwrite(fileDescriptor, "w_util_mean: %0.2f\n",         bw_rt_noc_ni_narrow_stats[cl_id].w_util_mean);
				                  $fwrite(fileDescriptor, "w_util_stddev: %0.2f\n",       bw_rt_noc_ni_narrow_stats[cl_id].w_util_stddev);

				                  // BW stats (narrow) - Close file
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

				                  // Latency (wide) - Open file
				                  $sformat(filePath, "%s/test%0d_noc_ni_burst_stats_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
				                  fileDescriptor = $fopen(filePath, "w"); 

				                  // Latency (wide) - Write header
				                  $fwrite(fileDescriptor, "iter, t0, t1, lat, bw, n_beats, dw_bit\n");

				                  // Latency (wide) - Write values
				                  if(DmaReadEnable) begin
				                    foreach (bw_rt_noc_ni_wide_stats[cl_id].r_burst_t0[bi]) begin
				                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
				                        bi,
				                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_t0[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_t1[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].r_latency_val[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].r_bw_val[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_n_beats[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].r_burst_dw[bi]
				                      );
				                    end
				                  end
				                  if(DmaWriteEnable) begin
				                    foreach (bw_rt_noc_ni_wide_stats[cl_id].w_burst_t0[bi]) begin
				                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
				                        bi,
				                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_t0[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_t1[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].w_latency_val[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].w_bw_val[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_n_beats[bi], 
				                        bw_rt_noc_ni_wide_stats[cl_id].w_burst_dw[bi]
				                      );
				                    end
				                  end

				                  // Latency (wide) - Close file
				                  $fclose(fileDescriptor);

				                  // Latency (narrow) - Open file
				                  $sformat(filePath, "%s/test%0d_noc_ni_narrow_burst_stats_cl_%0d.txt", fileDir, experimental_stats.id_test, cl_id);
				                  fileDescriptor = $fopen(filePath, "w"); 

				                  // Latency (narrow) - Write header
				                  $fwrite(fileDescriptor, "iter, t0, t1, lat, bw, n_beats, dw_bit\n");

				                  // Latency (narrow) - Write values
				                  if(DmaReadEnable) begin
				                    foreach (bw_rt_noc_ni_narrow_stats[cl_id].r_burst_t0[bi]) begin
				                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
				                        bi,
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_burst_t0[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_burst_t1[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_latency_val[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_bw_val[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_burst_n_beats[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].r_burst_dw[bi]
				                      );
				                    end
				                  end
				                  if(DmaWriteEnable) begin
				                    foreach (bw_rt_noc_ni_narrow_stats[cl_id].w_burst_t0[bi]) begin
				                      $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", 
				                        bi,
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_burst_t0[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_burst_t1[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_latency_val[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_bw_val[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_burst_n_beats[bi], 
				                        bw_rt_noc_ni_narrow_stats[cl_id].w_burst_dw[bi]
				                      );
				                    end
				                  end

				                  // Latency (narrow) - Close file
				                  $fclose(fileDescriptor);

				                  // Bursts before AXI-REALM (traffic generator side), one file per core
				                  for (int j = 0; j < NumCoresActive; j++) begin
				                    $sformat(filePath, "%s/test%0d_realm_in_burst_stats_cl_%0d_core_%0d.txt", fileDir, experimental_stats.id_test, cl_id, j);
				                    fileDescriptor = $fopen(filePath, "w");
				                    $fwrite(fileDescriptor, "iter, t0, t1, lat, bw, n_beats, dw_bit\n");
				                    if(DmaReadEnable) begin
				                      foreach (bw_rt_cl_stats[cl_id][j].r_burst_t0[bi]) begin
				                        $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", bi,
				                          bw_rt_cl_stats[cl_id][j].r_burst_t0[bi], bw_rt_cl_stats[cl_id][j].r_burst_t1[bi],
				                          bw_rt_cl_stats[cl_id][j].r_latency_val[bi], bw_rt_cl_stats[cl_id][j].r_bw_val[bi],
				                          bw_rt_cl_stats[cl_id][j].r_burst_n_beats[bi], bw_rt_cl_stats[cl_id][j].r_burst_dw[bi]);
				                      end
				                    end
				                    if(DmaWriteEnable) begin
				                      foreach (bw_rt_cl_stats[cl_id][j].w_burst_t0[bi]) begin
				                        $fwrite(fileDescriptor, "%0d, %0.2f, %0.2f, %0.2f, %0.2f, %0d, %0d\n", bi,
				                          bw_rt_cl_stats[cl_id][j].w_burst_t0[bi], bw_rt_cl_stats[cl_id][j].w_burst_t1[bi],
				                          bw_rt_cl_stats[cl_id][j].w_latency_val[bi], bw_rt_cl_stats[cl_id][j].w_bw_val[bi],
				                          bw_rt_cl_stats[cl_id][j].w_burst_n_beats[bi], bw_rt_cl_stats[cl_id][j].w_burst_dw[bi]);
				                      end
				                    end
				                    $fclose(fileDescriptor);
				                  end
				                end
				              end
				  `endif

				              NTest = NTest + 1;
				              tb_timer_cnt_value_old = tb_timer_cnt_value; // Store old counter value

				              `wait_n_clk(1);
            				end // interferer_task_period_loop
            			end // interferer_task_budget_loop
            		end // critical_task_period_loop
            	end // critical_task_budget_loop
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

