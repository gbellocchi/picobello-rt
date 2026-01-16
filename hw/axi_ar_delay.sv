// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "common_cells/registers.svh"
`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_ar_delay #(
  /// AXI bus configuration
  parameter floo_pkg::axi_cfg_t AxiCfg = '0,
  /// Delay values to model memory access cost
  parameter int unsigned DelayInput = 0, // Ck
  parameter int unsigned DelayOutput = 0, // Ck
  /// AR FIFO depth
  parameter int unsigned ArFifoDepth = 0,
  /// Max number of outstanding AR transactions
  parameter int unsigned ArNumTxns = 0,
  /// AXI in request channel
  parameter type axi_in_req_t   = logic,
  /// AXI in response channel
  parameter type axi_in_rsp_t   = logic,
  /// AXI out request channel
  parameter type axi_out_req_t  = logic,
  /// AXI out response channel
  parameter type axi_out_rsp_t  = logic,
  /// AXI AR channel
  parameter type axi_ar_chan_t  = logic
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,
  input  axi_in_req_t axi_req_i,
  output axi_in_rsp_t axi_rsp_o,
  output axi_out_req_t axi_req_o,
  input  axi_out_rsp_t axi_rsp_i
);

  // AXI FIFO
  axi_in_req_t axi_req_fifo;
  axi_in_rsp_t axi_rsp_fifo;

  // FIFO control
  logic ar_fifo_empty, ar_fifo_full;
  logic ar_accept_i;

  // FSM states
  typedef enum logic [1:0] {
      Idle, DelayFirstAr, BypassAr
  } state_e;

  state_e state_d, state_q;

  // Counters
  logic [AxiCfg.AddrWidth-1:0] ar_cnt_q, ar_cnt_d;

  // Delay counter control
  logic enable_ar_delay, load_ar_delay;

  // Residual delay counter output
  logic [AxiCfg.AddrWidth-1:0] count_out_ar_delay;

  // Delay AR channel
  if(DelayInput > 0) begin : gen_delay_ar_channel
    // Buffer incoming AR request before delaying it to detect back-to-back requests
    fifo_v3 #(
        .dtype            (axi_ar_chan_t),     
        .DEPTH            (ArFifoDepth),
        .FALL_THROUGH     (1'b0)
    ) i_ar_fifo_pre_delay (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),
        .flush_i          (1'b0),
        .testmode_i       (test_enable_i),
        .full_o           (ar_fifo_full),
        .empty_o          (ar_fifo_empty),
        .usage_o          (),
        .data_i           (axi_req_i.ar),
        .push_i           (axi_req_i.ar_valid && axi_rsp_o.ar_ready),
        .data_o           (axi_req_fifo.ar),
        .pop_i            (axi_req_fifo.ar_valid && axi_rsp_fifo.ar_ready)
    );

    assign axi_req_fifo.ar_valid  = ~ar_fifo_empty;
    assign axi_rsp_o.ar_ready = ~ar_fifo_full && ar_accept_i;

    // FSM to control AR delay insertion and which AR requests to bypass
    always_comb begin
        state_d = state_q;
        load_ar_delay    = 1'b0;
        enable_ar_delay  = 1'b0;
        axi_req_o.ar_valid = 1'b0;
        axi_rsp_fifo.ar_ready = 1'b0;
        ar_cnt_d = 0;
        ar_accept_i = 1'b0;

        unique case (state_q)

        // Wait for AR request
        Idle: begin
            // Accept incoming AR request
            ar_accept_i = 1'b1;
            if (axi_req_fifo.ar_valid) begin
                // Load delay counter
                load_ar_delay = 1'b1;
                ar_cnt_d = 0;
                state_d = DelayFirstAr;
                // Just one cycle delay
                if (DelayInput == 1) begin
                    state_d = BypassAr;
                end
            end
        end

        // Delay first AR request
        DelayFirstAr: begin
            // Accept incoming AR request
            ar_accept_i = 1'b1;
            enable_ar_delay = 1'b1;
            ar_cnt_d = 0;
            if (count_out_ar_delay == 0) begin
                state_d = BypassAr;
            end
        end

        // Bypass subsequent AR requests without delay (back-to-back)
        BypassAr: begin
            ar_accept_i = 1'b0;
            axi_req_o.ar_valid = 1'b1;
            axi_rsp_fifo.ar_ready = axi_rsp_i.ar_ready;
            if (axi_req_o.ar_valid && axi_rsp_i.ar_ready) begin
                ar_cnt_d = ar_cnt_q + 1;
            end else begin
                ar_cnt_d = ar_cnt_q;
            end
            if (ar_cnt_q == ArFifoDepth-1) begin
                state_d = Idle;
            end
        end

        default : /* default */;
        endcase
    end

    // Delay counter for AR channel
    counter #(
        .WIDTH      (AxiCfg.AddrWidth)
    ) i_ar_delay_cnt (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .clear_i    (1'b0),
        .en_i       (enable_ar_delay),
        .load_i     (load_ar_delay),
        .down_i     (1'b1),
        .d_i        (DelayInput),
        .q_o        (count_out_ar_delay),
        .overflow_o ()
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q <= Idle;
        end else begin
            state_q <= state_d;
        end
    end

    // Track AR handshakes during BypassAr state
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            ar_cnt_q <= 0;
        end else begin
            ar_cnt_q <= ar_cnt_d;
        end
    end
    
    // Route AR channel
    // assign axi_req_o.ar = axi_req_fifo.ar;

    always_comb begin
      `__AXI_TO_AR(, axi_req_o.ar, ., axi_req_fifo.ar, .)
      axi_req_o.ar.id = '0;
    end

  end else begin : gen_bypass_ar_channel
    // Bypass AR channel without delay insertion
    // assign axi_req_o.ar = axi_req_i.ar;

    always_comb begin
      `__AXI_TO_AR(, axi_req_o.ar, ., axi_req_i.ar, .)
      axi_req_o.ar.id = '0;
    end

    assign axi_req_o.ar_valid = axi_req_i.ar_valid;
    assign axi_rsp_o.ar_ready = axi_rsp_i.ar_ready;
  end

  // Bypass AW channel
  assign axi_req_o.aw       = axi_req_i.aw;
  assign axi_req_o.aw_valid = axi_req_i.aw_valid;
  assign axi_rsp_o.aw_ready = axi_rsp_i.aw_ready;

  // Bypass W channel
  assign axi_req_o.w        = axi_req_i.w;
  assign axi_req_o.w_valid  = axi_req_i.w_valid;
  assign axi_rsp_o.w_ready  = axi_rsp_i.w_ready;

  // Bypass R channel
  assign axi_rsp_o.r        = axi_rsp_i.r;
  assign axi_rsp_o.r_valid  = axi_rsp_i.r_valid;
  assign axi_req_o.r_ready  = axi_req_i.r_ready;

  // Bypass B channel
  assign axi_rsp_o.b        = axi_rsp_i.b;
  assign axi_rsp_o.b_valid  = axi_rsp_i.b_valid;
  assign axi_req_o.b_ready  = axi_req_i.b_ready;

endmodule