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

  // Queues
  int unsigned ar_outstanding [NumAxiIds][$];
  int unsigned aw_outstanding [NumAxiIds][$];
  int unsigned r_latency [$];
  int unsigned w_latency [$];
  real r_bw_t [$];
  real r_bw_val [$];
  real r_util_val [$];
  real w_bw_t [$];
  real w_bw_val [$];
  real w_util_val [$];

  // Control
  int unsigned prev_r_last;

  // AX channel counters
  int unsigned ar_cnt;
  int unsigned aw_cnt;
  int unsigned w_cnt;
  int unsigned r_cnt;

  // Read statistics
  real r_latency_mean;
  real r_latency_stddev;
  real r_bw_mean;
  real r_bw_stddev;
  real r_util_mean;
  real r_util_stddev;

  // Write statistics
  real w_latency_mean;
  real w_latency_stddev;
  real w_bw_mean;
  real w_bw_stddev;
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
      ar_in_flight_o += ar_outstanding[i].size();
    end
  end

  initial begin

    // Initialize AR channel counters
    ar_cnt = 0;
    r_cnt = 0;
    // Initialize queues
    for (int i = 0; i < NumAxiIds; i++) begin
      ar_outstanding[i].delete();
    end
    r_latency.delete();
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
    // Initialize read controls
    prev_r_last = 1;

    while(1) begin 

      // Wait for enable
      @(posedge cfg_i.en_r_cnt);

      // Initialize AR channel counters
      ar_cnt = 0;
      r_cnt = 0;

      // Initialize read controls
      prev_r_last = 1;

      // Initialize queues
      for (int i = 0; i < NumAxiIds; i++) begin
        ar_outstanding[i].delete();
      end
      r_latency.delete();
      r_bw_t.delete();
      r_bw_val.delete();
      r_util_val.delete();

      // Monitoring
      while(cfg_i.en_r_cnt) begin
        @(posedge clk_i);
        // If a handshake for an AR request is detected
        if (req_i.ar_valid && rsp_i.ar_ready) begin
          // Store absolute timestamp in queue
          ar_outstanding[req_i.ar.id].push_back(r_cycle_cnt_reg);
          ar_cnt++;
        end
        if (rsp_i.r_valid && req_i.r_ready) begin
          r_cnt++;
          if (prev_r_last) begin
            automatic int unsigned latency = r_cycle_cnt_reg - ar_outstanding[rsp_i.r.id].pop_front();
            // Calculate read latency comparing r and ar timestamps
            r_latency.push_back(latency);
            // Calculate bandwidth
            r_bw_t.push_back(real'(r_cycle_cnt_reg));
            r_bw_val.push_back(real'(r_cnt) * $bits(rsp_i.r.data) / real'(r_cycle_cnt_reg));
            r_util_val.push_back(real'(r_cnt) * 100 / real'(r_cycle_cnt_reg));
          end
          prev_r_last = rsp_i.r.last;
        end
      end

      @(posedge clk_i);

      /////////////
      // Latency //
      /////////////

      // Calculate mean value
      r_latency_mean = 0;
      foreach (r_latency[i]) begin
        r_latency_mean += r_latency[i];
      end
      if (r_latency.size() == 0) begin
        r_latency_mean = 0;
      end else begin
        r_latency_mean = r_latency_mean / r_latency.size();
      end

      // Calculate standard deviation
      r_latency_stddev = 0;
      foreach (r_latency[i]) begin
        r_latency_stddev += (r_latency[i] - r_latency_mean) ** 2;
      end
      if (r_latency.size() == 0) begin
        r_latency_stddev = 0;
      end else begin
        r_latency_stddev = $sqrt(r_latency_stddev / r_latency.size());
      end

      ///////////////
      // Bandwidth //
      ///////////////

      // Calculate mean value
      r_bw_mean = 0;
      if (r_cycle_cnt_reg == 0) begin
        r_bw_mean = 0;
      end else begin
        r_bw_mean = real'(r_cnt) * $bits(rsp_i.r.data) / real'(r_cycle_cnt_reg);
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

      // Calculate mean value of utilization
      r_util_mean = 0;
      if (r_cycle_cnt_reg == 0) begin
        r_util_mean = 0;
      end else begin
        r_util_mean = real'(r_cnt) * 100 / real'(r_cycle_cnt_reg);
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
      stats_o.r_bw_t = r_bw_t;
      stats_o.r_bw_val = r_bw_val;
      stats_o.r_latency_mean = r_latency_mean;
      stats_o.r_latency_stddev = r_latency_stddev;
      stats_o.r_bw_mean = r_bw_mean;
      stats_o.r_bw_stddev = r_bw_stddev;
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
      aw_in_flight_o += aw_outstanding[i].size();
    end
  end

  initial begin

    // Initialize AW channel counters
    aw_cnt = 0;
    w_cnt = 0;
    // Initialize queues
    for (int i = 0; i < NumAxiIds; i++) begin
      aw_outstanding[i].delete();
    end
    w_latency.delete();
    w_bw_t.delete();
    w_bw_val.delete();
    w_util_val.delete();
    // Initialize write statistics
    w_latency_mean = 0;
    w_latency_stddev = 0;
    w_bw_mean = 0;
    w_util_mean = 0;

    while(1) begin 

      // Wait for enable
      @(posedge cfg_i.en_w_cnt);

      // Initialize AW channel counters
      aw_cnt = 0;
      w_cnt = 0;

      // Initialize queues
      for (int i = 0; i < NumAxiIds; i++) begin
        aw_outstanding[i].delete();
      end
      w_latency.delete();
      w_bw_t.delete();
      w_bw_val.delete();
      w_util_val.delete();

      // Monitoring
      while(cfg_i.en_w_cnt) begin
        @(posedge clk_i);
        // If a handshake for an AW request is detected
        if (req_i.aw_valid && rsp_i.aw_ready) begin
          // Store absolute timestamp in queue
          aw_outstanding[req_i.aw.id].push_back(w_cycle_cnt_reg);
          aw_cnt++;
        end
        if (req_i.w_valid && rsp_i.w_ready) begin
          w_cnt++;
        end
        if (rsp_i.b_valid && req_i.b_ready) begin
          // Calculate write latency comparing w and aw timestamps
          w_latency.push_back(w_cycle_cnt_reg - aw_outstanding[rsp_i.b.id].pop_front());
          // Calculate bandwidth
          w_bw_t.push_back(real'(w_cycle_cnt_reg));
          w_bw_val.push_back(real'(w_cnt) * $bits(req_i.w.data) / real'(w_cycle_cnt_reg));
          w_util_val.push_back(real'(w_cnt) * 100 / real'(w_cycle_cnt_reg));
        end
      end

      /////////////
      // Latency //
      /////////////

      // Calculate mean value
      w_latency_mean = 0;
      foreach (w_latency[i]) begin
        w_latency_mean += w_latency[i];
      end
      if (w_latency.size() == 0) begin
        w_latency_mean = 0;
      end else begin
        w_latency_mean = w_latency_mean / w_latency.size();
      end

      // Calculate standard deviation
      w_latency_stddev = 0;
      foreach (w_latency[i]) begin
        w_latency_stddev += (w_latency[i] - w_latency_mean) ** 2;
      end
      if (w_latency.size() == 0) begin
        w_latency_stddev = 0;
      end else begin
        w_latency_stddev = $sqrt(w_latency_stddev / w_latency.size());
      end

      ///////////////
      // Bandwidth //
      ///////////////

      // Calculate mean value
      w_bw_mean = 0;
      if (w_cycle_cnt_reg == 0) begin
        w_bw_mean = 0;
      end else begin
        w_bw_mean = real'(w_cnt) * $bits(req_i.w.data) / real'(w_cycle_cnt_reg);
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

      // Calculate mean value of utilization
      w_util_mean = 0;
      if (w_cycle_cnt_reg == 0) begin
        w_util_mean = 0;
      end else begin
        w_util_mean = real'(w_cnt) * 100 / real'(w_cycle_cnt_reg);
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

      // Route read channel statistics
      stats_o.w_bw_t = w_bw_t;
      stats_o.w_bw_val = w_bw_val;
      stats_o.w_latency_mean = w_latency_mean;
      stats_o.w_latency_stddev = w_latency_stddev;
      stats_o.w_bw_mean = w_bw_mean;
      stats_o.w_bw_stddev = w_bw_stddev;
      stats_o.w_util_mean = w_util_mean;
      stats_o.w_util_stddev = w_util_stddev;

      // Wait for reset before to restart the monitoring loop
      @(posedge cfg_i.rst_w_cnt);
    end // infinite loop
  end // initial block
endmodule
