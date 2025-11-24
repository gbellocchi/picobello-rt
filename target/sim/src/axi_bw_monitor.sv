// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
//  - Tim Fischer <fischeti@iis.ee.ethz.ch>
//  - Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

/// A AXI4 Bus Monitor for measuring the throughput and latency of the AXI4 Bus
module axi_bw_monitor #(
  parameter type req_t = logic,
  parameter type rsp_t = logic,
  parameter type cfg_t = logic,
  parameter type stat_t = logic,
  parameter int unsigned AxiDataWidth = 32,
  parameter int unsigned AxiIdWidth = 4,
  parameter int unsigned NumAxiIds = 2**AxiIdWidth,
  parameter string Name = ""
) (
  input logic clk_i,
  input logic rst_ni,

  input req_t req_i,
  input rsp_t rsp_i,

  output logic [31:0] ar_in_flight_o,
  output logic [31:0] aw_in_flight_o,

  input cfg_t cfg_i,
  output stat_t stats_o
);
  // Cycle counters
  int unsigned r_cycle_cnt, r_cycle_cnt_reg;
  int unsigned w_cycle_cnt, w_cycle_cnt_reg;

  // AX channel counters
  int unsigned ar_total_cnt;
  int unsigned r_total_cnt;

  int unsigned aw_total_cnt;
  int unsigned w_total_cnt;

  // Outstanding bursts tracking
  int unsigned r_burst_id_t0 [NumAxiIds][$];
  int unsigned r_burst_id_t1 [NumAxiIds][$];
  int unsigned w_burst_id_t0 [NumAxiIds][$];
  int unsigned w_burst_id_t1 [NumAxiIds][$];

  // Read statistics
  int unsigned r_burst_t0[$];
  int unsigned r_burst_t1[$];
  int unsigned r_burst_n_beats[$];
  int unsigned r_burst_dw[$];

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

  // Write statistics
  int unsigned w_burst_t0[$];
  int unsigned w_burst_t1[$];
  int unsigned w_burst_n_beats[$];
  int unsigned w_burst_dw[$];
  
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

  ///////////////////////////
  // Monitor read channels //
  ///////////////////////////

  // Count read clock cycles
  always_comb 
  begin
    r_cycle_cnt = r_cycle_cnt_reg;

    if(cfg_i.rst_r_cnt) begin
      r_cycle_cnt = 0;
    end
    else if(cfg_i.en_r_cnt) begin
      r_cycle_cnt = r_cycle_cnt_reg + 1;
    end
  end

  always_ff@(posedge clk_i, negedge rst_ni) begin
    if(!rst_ni) begin
      r_cycle_cnt_reg <= 0;
    end
    else begin
      r_cycle_cnt_reg <= r_cycle_cnt;
    end
  end

  // Count ax requests
  always @(posedge clk_i) begin
    ar_in_flight_o = 0;
    for (int i = 0; i < NumAxiIds; i++) begin
      ar_in_flight_o += r_burst_id_t0[i].size();
    end
  end

  initial begin

    // Initialize AR channel counters
    ar_total_cnt = 0;
    r_total_cnt = 0;
    // Initialize queues
    for (int i = 0; i < NumAxiIds; i++) begin
      r_burst_id_t0[i].delete();
      r_burst_id_t1[i].delete();
    end
    r_burst_t0.delete();
    r_burst_t1.delete();
    r_burst_n_beats.delete();
    r_burst_dw.delete();
    r_latency_val.delete();
    r_bw_t.delete();
    r_bw_val.delete();
    r_util_val.delete();
    // Initialize read statistics
    r_latency_mean = 0;
    r_latency_stddev = 0;
    r_bw_mean = 0;
    r_bw_stddev = 0;
    r_util_mean = 0;
    r_util_stddev = 0;

    while(1) begin 

      // Wait for enable
      @(posedge cfg_i.en_r_cnt);

      // Initialize AR channel counters
      ar_total_cnt = 0;
      r_total_cnt = 0;

      // Initialize queues
      for (int i = 0; i < NumAxiIds; i++) begin
        r_burst_id_t0[i].delete();
        r_burst_id_t1[i].delete();
      end
      r_burst_t0.delete();
      r_burst_t1.delete();
      r_burst_n_beats.delete();
      r_burst_dw.delete();
      r_latency_val.delete();
      r_bw_t.delete();
      r_bw_val.delete();
      r_util_val.delete();

      // Monitoring
      while(cfg_i.en_r_cnt) begin
        @(posedge clk_i);
        // If a handshake for an AR request is detected
        if (req_i.ar_valid && rsp_i.ar_ready) begin
          // Store absolute timestamp in queue
          r_burst_id_t0[req_i.ar.id].push_back(r_cycle_cnt_reg);
          ar_total_cnt++;
        end
        if (rsp_i.r_valid && req_i.r_ready) begin
          r_total_cnt++;
          if (rsp_i.r.last) begin
            // Store absolute timestamp in queue
            r_burst_id_t1[rsp_i.r.id].push_back(r_cycle_cnt_reg);
            // Calculate read latency comparing r and ar timestamps
            r_burst_t0.push_back(r_burst_id_t0[rsp_i.r.id].pop_front());
            r_burst_t1.push_back(r_burst_id_t1[rsp_i.r.id].pop_front());
            r_burst_n_beats.push_back(r_total_cnt);
            r_burst_dw.push_back($bits(rsp_i.r.data));
          end
        end
      end

      @(posedge clk_i);

      /////////////
      // Latency //
      /////////////

      // Calculate values
      foreach (r_burst_t1[i]) begin
        r_latency_val[i] = real'(r_burst_t1[i] - r_burst_t0[i]);
      end
      
      // Calculate mean value
      r_latency_mean = 0;
      foreach (r_latency_val[i]) begin
        r_latency_mean += r_latency_val[i];
      end
      if (r_latency_val.size() == 0) begin
        r_latency_mean = 0;
      end else begin
        r_latency_mean = r_latency_mean / r_latency_val.size();
      end

      // Calculate standard deviation
      r_latency_stddev = 0;
      foreach (r_latency_val[i]) begin
        r_latency_stddev += (r_latency_val[i] - r_latency_mean) ** 2;
      end
      if (r_latency_val.size() == 0) begin
        r_latency_stddev = 0;
      end else begin
        r_latency_stddev = $sqrt(r_latency_stddev / r_latency_val.size());
      end

      ///////////////
      // Bandwidth //
      ///////////////

      // Calculate values
      foreach (r_burst_t1[i]) begin
        r_bw_t[i] = real'(r_burst_t1[i]);
        r_bw_val[i] = (r_burst_n_beats[i] * r_burst_dw[i]) / real'(r_burst_t1[i]);
      end

      // Calculate mean value
      r_bw_mean = 0;
      if (r_cycle_cnt_reg == 0) begin
        r_bw_mean = 0;
      end else begin
        r_bw_mean = real'(r_total_cnt) * $bits(rsp_i.r.data) / real'(r_cycle_cnt_reg);
      end

      // Calculate standard deviation
      r_bw_stddev = 0;
      foreach (r_bw_val[i]) begin
        r_bw_stddev += (r_bw_val[i] - r_bw_mean) ** 2;
      end
      if (r_bw_val.size() == 0) begin
        r_bw_stddev = 0;
      end else begin
        r_bw_stddev = $sqrt(r_bw_stddev / r_bw_val.size());
      end

      /////////////////
      // Utilization //
      /////////////////

      // Calculate values
      foreach (r_burst_t1[i]) begin
        r_util_val[i] = (r_burst_n_beats[i] * 100) / real'(r_burst_t1[i]);
      end

      // Calculate mean value of utilization
      r_util_mean = 0;
      if (r_cycle_cnt_reg == 0) begin
        r_util_mean = 0;
      end else begin
        r_util_mean = real'(r_total_cnt) * 100 / real'(r_cycle_cnt_reg);
      end

      // Calculate standard deviation
      r_util_stddev = 0;
      foreach (r_util_val[i]) begin
        r_util_stddev += (r_util_val[i] - r_util_mean) ** 2;
      end
      if (r_util_val.size() == 0) begin
        r_util_stddev = 0;
      end else begin
        r_util_stddev = $sqrt(r_util_stddev / r_util_val.size());
      end

      @(posedge clk_i);

      // Route read channel statistics
      // -- Burst
      stats_o.r_burst_t0 = r_burst_t0;
      stats_o.r_burst_t1 = r_burst_t1;
      stats_o.r_burst_n_beats = r_burst_n_beats;
      stats_o.r_burst_dw = r_burst_dw;
      // -- Latency
      stats_o.r_latency_val = r_latency_val;
      stats_o.r_latency_mean = r_latency_mean;
      stats_o.r_latency_stddev = r_latency_stddev;
      // -- Bandwidth
      stats_o.r_bw_t = r_bw_t;
      stats_o.r_bw_val = r_bw_val;
      stats_o.r_bw_mean = r_bw_mean;
      stats_o.r_bw_stddev = r_bw_stddev;
      // -- Utilization
      stats_o.r_util_val = r_util_val;
      stats_o.r_util_mean = r_util_mean;
      stats_o.r_util_stddev = r_util_stddev;

      // Wait for reset before to restart the monitoring loop
      @(posedge cfg_i.rst_r_cnt);
    end // infinite loop
  end // initial block

  ////////////////////////////
  // Monitor write channels //
  ////////////////////////////

  // Count read clock cycles
  always_comb 
  begin
    w_cycle_cnt = w_cycle_cnt_reg;

    if(cfg_i.rst_w_cnt) begin
      w_cycle_cnt = 0;
    end
    else if(cfg_i.en_w_cnt) begin
      w_cycle_cnt = w_cycle_cnt_reg + 1;
    end
  end

  always_ff@(posedge clk_i, negedge rst_ni) begin
    if(!rst_ni) begin
      w_cycle_cnt_reg <= 0;
    end
    else begin
      w_cycle_cnt_reg <= w_cycle_cnt;
    end
  end

  // Count ax requests
  always @(posedge clk_i) begin
    aw_in_flight_o = 0;
    for (int i = 0; i < NumAxiIds; i++) begin
      aw_in_flight_o += w_burst_id_t0[i].size();
    end
  end

  initial begin

    // Initialize AW channel counters
    aw_total_cnt = 0;
    w_total_cnt = 0;
    // Initialize queues
    for (int i = 0; i < NumAxiIds; i++) begin
      w_burst_id_t0[i].delete();
      w_burst_id_t1[i].delete();
    end
    w_burst_t0.delete();
    w_burst_t1.delete();
    w_burst_n_beats.delete();
    w_burst_dw.delete();
    w_latency_val.delete();
    w_bw_t.delete();
    w_bw_val.delete();
    w_util_val.delete();
    // Initialize write statistics
    w_latency_mean = 0;
    w_latency_stddev = 0;
    w_bw_mean = 0;
    w_bw_stddev = 0;
    w_util_mean = 0;
    w_util_stddev = 0;

    while(1) begin 

      // Wait for enable
      @(posedge cfg_i.en_w_cnt);

      // Initialize AW channel counters
      aw_total_cnt = 0;
      w_total_cnt = 0;

      // Initialize queues
      for (int i = 0; i < NumAxiIds; i++) begin
        w_burst_id_t0[i].delete();
        w_burst_id_t1[i].delete();
      end
      w_burst_t0.delete();
      w_burst_t1.delete();
      w_burst_n_beats.delete();
      w_burst_dw.delete();
      w_latency_val.delete();
      w_bw_t.delete();
      w_bw_val.delete();
      w_util_val.delete();

      // Monitoring
      while(cfg_i.en_w_cnt) begin
        @(posedge clk_i);
        // If a handshake for an AW request is detected
        if (req_i.aw_valid && rsp_i.aw_ready) begin
          // Store absolute timestamp in queue
          w_burst_id_t0[req_i.aw.id].push_back(w_cycle_cnt_reg);
          aw_total_cnt++;
        end
        if (req_i.w_valid && rsp_i.w_ready) begin
          w_total_cnt++;
        end
        if (rsp_i.b_valid && req_i.b_ready) begin
          // Store absolute timestamp in queue
          w_burst_id_t1[rsp_i.b.id].push_back(w_cycle_cnt_reg);
          // Calculate write latency comparing w and aw timestamps
          w_burst_t0.push_back(w_burst_id_t0[rsp_i.b.id].pop_front());
          w_burst_t1.push_back(w_burst_id_t1[rsp_i.b.id].pop_front());
          w_burst_n_beats.push_back(w_total_cnt);
          w_burst_dw.push_back($bits(req_i.w.data));
        end
      end

      /////////////
      // Latency //
      /////////////

      // Calculate values
      foreach (w_burst_t1[i]) begin
        w_latency_val[i] = real'(w_burst_t1[i] - w_burst_t0[i]);
      end

      // Calculate mean value
      w_latency_mean = 0;
      foreach (w_latency_val[i]) begin
        w_latency_mean += w_latency_val[i];
      end
      if (w_latency_val.size() == 0) begin
        w_latency_mean = 0;
      end else begin
        w_latency_mean = w_latency_mean / w_latency_val.size();
      end

      // Calculate standard deviation
      w_latency_stddev = 0;
      foreach (w_latency_val[i]) begin
        w_latency_stddev += (w_latency_val[i] - w_latency_mean) ** 2;
      end
      if (w_latency_val.size() == 0) begin
        w_latency_stddev = 0;
      end else begin
        w_latency_stddev = $sqrt(w_latency_stddev / w_latency_val.size());
      end

      ///////////////
      // Bandwidth //
      ///////////////

      // Calculate values
      foreach (w_burst_t1[i]) begin
        w_bw_t[i] = real'(w_burst_t1[i]);
        w_bw_val[i] = (w_burst_n_beats[i] * w_burst_dw[i]) / real'(w_burst_t1[i]);
      end

      // Calculate mean value
      w_bw_mean = 0;
      if (w_cycle_cnt_reg == 0) begin
        w_bw_mean = 0;
      end else begin
        w_bw_mean = real'(w_total_cnt) * $bits(req_i.w.data) / real'(w_cycle_cnt_reg);
      end

      // Calculate standard deviation
      w_bw_stddev = 0;
      foreach (w_bw_val[i]) begin
        w_bw_stddev += (w_bw_val[i] - w_bw_mean) ** 2;
      end
      if (w_bw_val.size() == 0) begin
        w_bw_stddev = 0;
      end else begin
        w_bw_stddev = $sqrt(w_bw_stddev / w_bw_val.size());
      end

      /////////////////
      // Utilization //
      /////////////////

      // Calculate values
      foreach (w_burst_t1[i]) begin
        w_util_val[i] = (w_burst_n_beats[i] * 100) / real'(w_burst_t1[i]);
      end

      // Calculate mean value of utilization
      w_util_mean = 0;
      if (w_cycle_cnt_reg == 0) begin
        w_util_mean = 0;
      end else begin
        w_util_mean = real'(w_total_cnt) * 100 / real'(w_cycle_cnt_reg);
      end

      // Calculate standard deviation
      w_util_stddev = 0;
      foreach (w_util_val[i]) begin
        w_util_stddev += (w_util_val[i] - w_util_mean) ** 2;
      end
      if (w_util_val.size() == 0) begin
        w_util_stddev = 0;
      end else begin
        w_util_stddev = $sqrt(w_util_stddev / w_util_val.size());
      end

      // Route write channel statistics
      // -- Burst
      stats_o.w_burst_t0 = w_burst_t0;
      stats_o.w_burst_t1 = w_burst_t1;
      stats_o.w_burst_n_beats = w_burst_n_beats;
      stats_o.w_burst_dw = w_burst_dw;
      // -- Latency
      stats_o.w_latency_val = w_latency_val;
      stats_o.w_latency_mean = w_latency_mean;
      stats_o.w_latency_stddev = w_latency_stddev;
      // -- Bandwidth
      stats_o.w_bw_t = w_bw_t;
      stats_o.w_bw_val = w_bw_val;
      stats_o.w_bw_mean = w_bw_mean;
      stats_o.w_bw_stddev = w_bw_stddev;
      // -- Utilization
      stats_o.w_util_val = w_util_val;
      stats_o.w_util_mean = w_util_mean;
      stats_o.w_util_stddev = w_util_stddev;

      // Wait for reset before to restart the monitoring loop
      @(posedge cfg_i.rst_w_cnt);
    end // infinite loop
  end // initial block
endmodule
