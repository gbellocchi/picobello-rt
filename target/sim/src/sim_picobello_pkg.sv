// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

package sim_picobello_pkg;

  import floo_pkg::*;

  ////////////////////////
  // Experimental Setup //
  ////////////////////////

  typedef struct {
    // Setup parameters
    int unsigned id_test; // Test ID
    // SoC parameters
    int unsigned n_cl_critical; // Number of critical task clusters
    int unsigned n_cl_interf; // Number of interferer clusters
    int unsigned n_acc_cl; // Number of accelerators per cluster
    int unsigned n_clx_mem; // Number of clusters per memory tile
    // NoC parameters
    int unsigned router_fifo_in_depth; // Router input FIFO depth
    int unsigned router_fifo_out_depth; // Router output FIFO depth
    int unsigned ni_max_oustanding_txns; // Network interface max outstanding transactions
    int unsigned ni_max_unique_ids; // Network interface max unique IDs
    // Realm tile parameters
    real traffic_gen_traffic_dim; // Traffic generator traffic dimension
    real traffic_gen_compute_dim; // Traffic generator compute dimension
    int unsigned burst_length; // Burst length
    // Results
    int unsigned t_exec_time_ck; // Execution time [clock cycles]
  } experimental_stats_t;

  /////////////////////
  // AXI BW Monitors //
  /////////////////////

  // AXI BW monitor configuration struct
  typedef struct packed {
    // Read channel
    logic en_r_cnt;
    logic rst_r_cnt;
    // Write channel
    logic en_w_cnt;
    logic rst_w_cnt;
  } bw_monitor_cfg_t;

  typedef struct {
    // Read channel
    int unsigned r_burst_t0 [$];
    int unsigned r_burst_t1 [$];
    int unsigned r_burst_n_beats [$];
    int unsigned r_burst_dw [$];
    real r_latency_val [$];
    real r_latency_mean;
    real r_latency_stddev;
    real r_bw_t [$];
    real r_bw_val [$];
    real r_bw_mean;
    real r_bw_stddev;
    real r_util_val [$];
    real r_util_mean;
    real r_util_stddev;
    // Write channel
    int unsigned w_burst_t0 [$];
    int unsigned w_burst_t1 [$];
    int unsigned w_burst_n_beats [$];
    int unsigned w_burst_dw [$];
    real w_latency_val [$];
    real w_latency_mean;
    real w_latency_stddev;
    real w_bw_t [$];
    real w_bw_val [$];
    real w_bw_mean;
    real w_bw_stddev;
    real w_util_val [$];
    real w_util_mean;
    real w_util_stddev;
  } bw_monitor_stats_t;

endpackage
