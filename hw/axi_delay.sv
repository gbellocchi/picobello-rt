// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "common_cells/registers.svh"
`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_shift #(
  /// Delay value to model memory access cost (in clock cycles)
  parameter int unsigned DelayInput = 0, // Ck
  /// AXI channel type
  parameter type axi_chan_t  = logic,
  parameter bit ChTypeAr = 1'b0,
  parameter bit ChTypeAw = 1'b0,
  parameter bit ChTypeW = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  // Input AXI channel
  input  axi_chan_t axi_ch_i,
  input  logic axi_valid_i,
  output logic axi_ready_o,
  // Output AXI channel
  output axi_chan_t axi_ch_o,
  output logic axi_valid_o,
  input  logic axi_ready_i
);

  axi_chan_t [DelayInput:0] axi_ch_shift;
  logic [DelayInput:0] axi_valid_shift;
  logic [DelayInput:0] axi_ready_shift;

  assign axi_ch_shift[0] = axi_ch_i;
  assign axi_valid_shift[0] = axi_valid_i;
  assign axi_ready_o = axi_ready_shift[0];

  for (genvar i = 0; i < DelayInput; i++) begin
    spill_register #(
      .T       ( axi_chan_t ),
      .Bypass  ( 1'b0       )
    ) i_reg_aw (
      .clk_i   ( clk_i                ),
      .rst_ni  ( rst_ni               ),
      .valid_i ( axi_valid_shift[i]     ),
      .ready_o ( axi_ready_shift[i]     ),
      .data_i  ( axi_ch_shift[i]        ),
      .valid_o ( axi_valid_shift[i+1]   ),
      .ready_i ( axi_ready_shift[i+1]   ),
      .data_o  ( axi_ch_shift[i+1]      )
    );
  end

  assign axi_ch_o = axi_ch_shift[DelayInput];
  assign axi_valid_o = axi_valid_shift[DelayInput];
  assign axi_ready_shift[DelayInput] = axi_ready_i;

endmodule

// Delay module for forward AXI channels (AR, AW, W).
module axi_delay #(
  /// Delay value to model memory access cost (in clock cycles)
  parameter int unsigned DelayInput = 0, // Ck
  /// AXI in request channel
  parameter type axi_in_req_t   = logic,
  /// AXI in response channel
  parameter type axi_in_rsp_t   = logic,
  /// AXI out request channel
  parameter type axi_out_req_t  = logic,
  /// AXI out response channel
  parameter type axi_out_rsp_t  = logic,
  /// AXI AR channel
  parameter type axi_ar_chan_t  = logic,
  /// AXI AW channel
  parameter type axi_aw_chan_t  = logic,
  /// AXI W channel
  parameter type axi_w_chan_t  = logic
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,
  input  axi_in_req_t axi_req_i,
  output axi_in_rsp_t axi_rsp_o,
  output axi_out_req_t axi_req_o,
  input  axi_out_rsp_t axi_rsp_i
);

  // Local AXI4 signals
  axi_out_req_t axi_req_delay;
  axi_out_rsp_t axi_rsp_delay;

  ////////////////
  // AR channel //
  ////////////////

  if(DelayInput > 0) begin : gen_delay_ar_channel
    axi_shift #(
      .DelayInput (DelayInput),
      .axi_chan_t (axi_ar_chan_t),
      .ChTypeAr (1'b1),
      .ChTypeAw (1'b0),
      .ChTypeW  (1'b0)
    ) i_axi_shift_ar (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .axi_ch_i    (axi_req_i.ar),
      .axi_valid_i (axi_req_i.ar_valid),
      .axi_ready_o (axi_rsp_o.ar_ready),
      .axi_ch_o    (axi_req_o.ar),
      .axi_valid_o (axi_req_o.ar_valid),
      .axi_ready_i (axi_rsp_i.ar_ready)
    );
  end else begin : gen_bypass_ar_channel
    assign axi_req_o.ar = axi_req_i.ar;
    assign axi_req_o.ar_valid = axi_req_i.ar_valid;
    assign axi_rsp_o.ar_ready = axi_rsp_i.ar_ready;
  end

  ////////////////
  // AW channel //
  ////////////////

  if(DelayInput > 0) begin : gen_delay_aw_channel
    axi_shift #(
      .DelayInput (DelayInput),
      .axi_chan_t (axi_aw_chan_t),
      .ChTypeAr (1'b0),
      .ChTypeAw (1'b1),
      .ChTypeW  (1'b0)
    ) i_axi_shift_aw (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .axi_ch_i    (axi_req_i.aw),
      .axi_valid_i (axi_req_i.aw_valid),
      .axi_ready_o (axi_rsp_o.aw_ready),
      .axi_ch_o    (axi_req_o.aw),
      .axi_valid_o (axi_req_o.aw_valid),
      .axi_ready_i (axi_rsp_i.aw_ready)
    );
  end else begin : gen_bypass_aw_channel
    assign axi_req_o.aw = axi_req_i.aw;
    assign axi_req_o.aw_valid = axi_req_i.aw_valid;
    assign axi_rsp_o.aw_ready = axi_rsp_i.aw_ready;
  end

  ///////////////
  // W channel //
  ///////////////

  if(DelayInput > 0) begin : gen_delay_w_channel
    axi_shift #(
      .DelayInput (DelayInput),
      .axi_chan_t (axi_w_chan_t),
      .ChTypeAr (1'b0),
      .ChTypeAw (1'b0),
      .ChTypeW  (1'b1)
    ) i_axi_shift_w (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),
      .axi_ch_i    (axi_req_i.w),
      .axi_valid_i (axi_req_i.w_valid),
      .axi_ready_o (axi_rsp_o.w_ready),
      .axi_ch_o    (axi_req_o.w),
      .axi_valid_o (axi_req_o.w_valid),
      .axi_ready_i (axi_rsp_i.w_ready)
    );
  end else begin : gen_bypass_w_channel
    assign axi_req_o.w = axi_req_i.w;
    assign axi_req_o.w_valid = axi_req_i.w_valid;
    assign axi_rsp_o.w_ready = axi_rsp_i.w_ready;
  end
  
  ///////////////
  // R channel //
  ///////////////

  // Bypass
  assign axi_rsp_o.r        = axi_rsp_i.r;
  assign axi_rsp_o.r_valid  = axi_rsp_i.r_valid;
  assign axi_req_o.r_ready  = axi_req_i.r_ready;

  ///////////////
  // B channel //
  ///////////////

  // Bypass
  assign axi_rsp_o.b        = axi_rsp_i.b;
  assign axi_rsp_o.b_valid  = axi_rsp_i.b_valid;
  assign axi_req_o.b_ready  = axi_req_i.b_ready;

endmodule