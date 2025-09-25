// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

package sim_picobello_pkg;

  ////////////////////////
  // Experimental Setup //
  ////////////////////////

  typedef struct {
    // string name;
    // Setup parameters
    real id_test; // Test ID
    real n_test_cl; // Number of test clusters
    real n_accx_cl; // Number of accelerators per cluster
    real n_clx_mem; // Number of clusters per memory tile
    real traffic_gen_traffic_dim; // Traffic generator traffic dimension
    real traffic_gen_compute_dim; // Traffic generator compute dimension
    real burst_length; // Burst length
    real t_exec_time_ck; // Execution time [clock cycles]
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
    // string name;
    // Read channel
    real r_latency_mean;
    real r_latency_stddev;
    real r_bw_t [$];
    real r_bw_val [$];
    real r_bw_mean;
    real r_util_mean;
    // Write channel
    real w_latency_mean;
    real w_latency_stddev;
    real w_bw_t [$];
    real w_bw_val [$];
    real w_bw_mean;
    real w_util_mean;
  } bw_monitor_stats_t;

endpackage
