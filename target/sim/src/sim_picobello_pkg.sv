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

  // TB timing
  localparam time ClkPeriod = 10ns; // Clock period
  parameter time ApplTime = 100ps; // Delay value assignment
  parameter time TestTime = 500ps; // Delay transaction start

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
    real read_traffic_dim; // Read traffic dimension
    real read_compute_dim; // Read compute dimension
    real write_traffic_dim; // Write traffic dimension
    real write_compute_dim; // Write compute dimension
    int unsigned burst_length; // Burst length
    // Results
    int unsigned t_exec_time_ck[$]; // Execution time [clock cycles]
  } experimental_stats_t;

  ///////////
  // Timer //
  ///////////

  // Timer counter (used during RTL simulation of the FPGA top)
  typedef struct packed {
    logic        write_counter_i; // [Input] Counter overwrite control
    logic [31:0] counter_value_i; // [Input] Counter value to set
    logic        reset_count_i; // [Input] Counter reset control
    logic        enable_count_i; // [Input] Counter enable control - to increase the counter value
    logic [31:0] compare_value_i; // [Input] Comparator value - to compare with the counter value
    // logic [32-1:0] counter_value_o; // [Output] Counter value
    // logic          target_reached_o; // [Output] Comparator value flag
  } timer_cfg_t;

  // Timer value
  typedef struct packed {
    logic [31:0] t0;
    logic [31:0] t1;
  } timer_val_t;

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
