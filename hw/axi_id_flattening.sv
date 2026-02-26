// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "common_cells/registers.svh"
`include "axi/assign.svh"
`include "axi/typedef.svh"

// Force AXI IDs to a hardwired value, thus flattening the ID space. This behavior is not compliant with the AXI specification. However, it can be used to easily simulate the behavior of AXI subordinates (e.g., memories) not capable of processing multiple oustanding transactions with different AXI IDs. Indeed, by flattening the ID space, the subordinate IP would perceive each outstanding transaction as having the same AXI ID.
module axi_id_flattening #(
  /// AXI ID flattening
  parameter bit          ReadEnable    = 1'b1,
  parameter int unsigned ReadIdValue   = '0,
  parameter bit          WriteEnable   = 1'b1,
  parameter int unsigned WriteIdValue  = '0,
  /// AXI in request channel
  parameter type         axi_in_req_t  = logic,
  /// AXI in response channel
  parameter type         axi_in_rsp_t  = logic,
  /// AXI out request channel
  parameter type         axi_out_req_t = logic,
  /// AXI out response channel
  parameter type         axi_out_rsp_t = logic,
  /// AXI AR channel
  parameter type         axi_ar_chan_t = logic,
  /// AXI AW channel
  parameter type         axi_aw_chan_t = logic,
  /// AXI W channel
  parameter type         axi_w_chan_t  = logic
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         test_enable_i,
  input  axi_in_req_t  axi_req_i,
  output axi_in_rsp_t  axi_rsp_o,
  output axi_out_req_t axi_req_o,
  input  axi_out_rsp_t axi_rsp_i
);

  ////////////////
  // AR channel //
  ////////////////

  always_comb begin
    `__AXI_TO_AR(, axi_req_o.ar, ., axi_req_i.ar, .)
    axi_req_o.ar.id = ReadEnable ? ReadIdValue : axi_req_o.ar.id;
  end
  assign axi_req_o.ar_valid = axi_req_i.ar_valid;
  assign axi_rsp_o.ar_ready = axi_rsp_i.ar_ready;

  ////////////////
  // AW channel //
  ////////////////

  always_comb begin
    `__AXI_TO_AW(, axi_req_o.aw, ., axi_req_i.aw, .)
    axi_req_o.aw.id = WriteEnable ? WriteIdValue : axi_req_o.aw.id;
  end
  assign axi_req_o.aw_valid = axi_req_i.aw_valid;
  assign axi_rsp_o.aw_ready = axi_rsp_i.aw_ready;

  ///////////////
  // W channel //
  ///////////////

  always_comb begin
    `__AXI_TO_W(, axi_req_o.w, ., axi_req_i.w, .)
  end
  assign axi_req_o.w_valid = axi_req_i.w_valid;
  assign axi_rsp_o.w_ready = axi_rsp_i.w_ready;

  ///////////////
  // R channel //
  ///////////////

  // Bypass
  assign axi_rsp_o.r       = axi_rsp_i.r;
  assign axi_rsp_o.r_valid = axi_rsp_i.r_valid;
  assign axi_req_o.r_ready = axi_req_i.r_ready;

  ///////////////
  // B channel //
  ///////////////

  // Bypass
  assign axi_rsp_o.b       = axi_rsp_i.b;
  assign axi_rsp_o.b_valid = axi_rsp_i.b_valid;
  assign axi_req_o.b_ready = axi_req_i.b_ready;

endmodule
