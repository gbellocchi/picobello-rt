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
  real r_bw;
  real r_util;

  // Write statistics
  real w_latency_mean;
  real w_latency_stddev;
  real w_bw;
  real w_util;

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
    while(1) begin 
      ar_cnt = 0;
      r_cnt = 0;
      r_latency_mean = 0;
      r_latency_stddev = 0;
      r_bw = 0;
      r_util = 0;
      prev_r_last = 1;

      @(posedge cfg_i.en_r_cnt);

      while(cfg_i.en_r_cnt) begin
        @(posedge clk_i);
        if (req_i.ar_valid && rsp_i.ar_ready) begin
          ar_outstanding[req_i.ar.id].push_back(r_cycle_cnt_reg);
          ar_cnt++;
        end
        if (rsp_i.r_valid && req_i.r_ready) begin
          r_cnt++;
          if (prev_r_last) begin
            r_latency.push_back(r_cycle_cnt_reg - ar_outstanding[rsp_i.r.id].pop_front());
          end
          prev_r_last = rsp_i.r.last;
        end
      end

      // Calculate the average of all latencies
      foreach (r_latency[i]) begin
        r_latency_mean += r_latency[i];
      end
      if (r_latency.size() == 0) begin
        r_latency_mean = 0;
      end else begin
        r_latency_mean = r_latency_mean / r_latency.size();
      end

      // Calculate the standard deviation of all latencies
      foreach (r_latency[i]) begin
        r_latency_stddev += (r_latency[i] - r_latency_mean) ** 2;
      end
      if (r_latency.size() == 0) begin
        r_latency_stddev = 0;
      end else begin
        r_latency_stddev = $sqrt(r_latency_stddev / r_latency.size());
      end

      // Calculate the BW and utilization
      r_bw = real'(r_cnt) * $bits(rsp_i.r.data) / real'(r_cycle_cnt_reg);
      r_util = real'(r_cnt) * 100 / real'(r_cycle_cnt_reg);

      // Route read channel statistics
      stats_o.r_latency_mean = r_latency_mean;
      stats_o.r_latency_stddev = r_latency_stddev;
      stats_o.r_bw = r_bw;
      stats_o.r_util = r_util;
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
    while(1) begin 
      aw_cnt = 0;
      w_cnt = 0;
      w_latency_mean = 0;
      w_latency_stddev = 0;
      w_bw = 0;
      w_util = 0;

      @(posedge cfg_i.en_w_cnt);

      while(cfg_i.en_w_cnt) begin
        @(posedge clk_i);
        if (req_i.aw_valid && rsp_i.aw_ready) begin
          aw_outstanding[req_i.aw.id].push_back(w_cycle_cnt_reg);
          aw_cnt++;
        end
        if (req_i.w_valid && rsp_i.w_ready) begin
          w_cnt++;
        end
        if (rsp_i.b_valid && req_i.b_ready) begin
          w_latency.push_back(w_cycle_cnt_reg - aw_outstanding[rsp_i.b.id].pop_front());
        end
      end

      // Calculate the average of all latencies
      foreach (w_latency[i]) begin
        w_latency_mean += w_latency[i];
      end
      if (w_latency.size() == 0) begin
        w_latency_mean = 0;
      end else begin
        w_latency_mean = w_latency_mean / w_latency.size();
      end
      // Calculate the standard deviation of all latencies
      foreach (w_latency[i]) begin
        w_latency_stddev += (w_latency[i] - w_latency_mean) ** 2;
      end
      if (w_latency.size() == 0) begin
        w_latency_stddev = 0;
      end else begin
        w_latency_stddev = $sqrt(w_latency_stddev / w_latency.size());
      end

      // Calculate the BW and utilization
      w_bw = real'(w_cnt) * $bits(req_i.w.data) / real'(w_cycle_cnt_reg);
      w_util = real'(w_cnt) * 100 / real'(w_cycle_cnt_reg);

      // Route write channel statistics
      stats_o.w_latency_mean = w_latency_mean;
      stats_o.w_latency_stddev = w_latency_stddev;
      stats_o.w_bw = w_bw;
      stats_o.w_util = w_util;
    end // infinite loop
  end // initial block
endmodule
