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
    parameter bit          AxiReadFlattenEnable  = 1'b1,
    parameter int unsigned AxiReadIdValue        = '0,
    parameter bit          AxiWriteFlattenEnable = 1'b1,
    parameter int unsigned AxiWriteIdValue       = '0,
    /// Maximum number of non-atomic outstanding requests
    parameter int          MaxTxns               = 32'd0,
    /// AXI Address Width
    parameter int unsigned AxiAddrWidth          = 0,
    /// AXI Data Width
    parameter int unsigned AxiDataWidth          = 0,
    /// AXI ID Width
    parameter int unsigned AxiIdWidth            = 0,
    /// AXI User Width
    parameter int unsigned AxiUserWidth          = 0,
    /// AXI in request channel
    parameter type         axi_in_req_t          = logic,
    /// AXI in response channel
    parameter type         axi_in_rsp_t          = logic,
    /// AXI out request channel
    parameter type         axi_out_req_t         = logic,
    /// AXI out response channel
    parameter type         axi_out_rsp_t         = logic,
    /// AXI AR channel
    parameter type         axi_ar_chan_t         = logic,
    /// AXI AW channel
    parameter type         axi_aw_chan_t         = logic,
    /// AXI W channel
    parameter type         axi_w_chan_t          = logic
) (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         test_enable_i,
    input  axi_in_req_t  axi_req_i,
    output axi_in_rsp_t  axi_rsp_o,
    output axi_out_req_t axi_req_o,
    input  axi_out_rsp_t axi_rsp_i
);
  typedef logic [AxiIdWidth-1:0] fifo_data_t;

  // ARID FIFO
  fifo_data_t fifo_ar_id_i;
  fifo_data_t fifo_r_id_o;
  logic fifo_ar_id_full;
  logic fifo_ar_id_push;
  logic fifo_ar_id_pop;

  // AWID FIFO
  fifo_data_t fifo_aw_id_i;
  fifo_data_t fifo_aw_id_o;
  logic fifo_aw_id_full;
  logic fifo_aw_id_push;
  logic fifo_aw_id_pop;

  ////////////////
  // AR channel //
  ////////////////

  if (AxiReadFlattenEnable) begin : gen_id_flatten_ar_channel
    // Buffer ARID
    assign fifo_ar_id_i = axi_req_i.ar.id;

    // Buffer only when handshake condition is satisfied
    assign fifo_ar_id_push = axi_req_o.ar_valid && axi_rsp_i.ar_ready;

    // Read a new ARID after the previous burst terminates
    assign fifo_ar_id_pop = axi_rsp_o.r_valid && axi_req_i.r_ready && axi_rsp_o.r.last;

    fifo_v3 #(
        .FALL_THROUGH(1'b1),
        .DEPTH       (MaxTxns),
        .dtype       (fifo_data_t)
    ) i_arid_fifo (
        .clk_i,
        .rst_ni,
        .flush_i   (1'b0),
        .testmode_i(test_enable_i),
        .full_o    (fifo_ar_id_full),
        .empty_o   (),
        .usage_o   (),
        .data_i    (fifo_ar_id_i),
        .push_i    (fifo_ar_id_push),
        .data_o    (fifo_r_id_o),
        .pop_i     (fifo_ar_id_pop)
    );

    // Output interface with flattened ARID
    always_comb begin
      `__AXI_TO_AR(, axi_req_o.ar, ., axi_req_i.ar, .)
      axi_req_o.ar.id = AxiReadIdValue;
    end
    assign axi_req_o.ar_valid = axi_req_i.ar_valid && !fifo_ar_id_full;
    assign axi_rsp_o.ar_ready = axi_rsp_i.ar_ready && !fifo_ar_id_full;

  end else begin : gen_bypass_ar_channel
    // Bypass
    assign axi_req_o.ar = axi_req_i.ar;
    assign axi_req_o.ar_valid = axi_req_i.ar_valid;
    assign axi_rsp_o.ar_ready = axi_rsp_i.ar_ready;
  end

  ///////////////
  // R channel //
  ///////////////

  if (AxiReadFlattenEnable) begin : gen_id_flatten_r_channel
    // Read original ARID from FIFO
    always_comb begin
      `__AXI_TO_R(, axi_rsp_o.r, ., axi_rsp_i.r, .)
      axi_rsp_o.r.id = fifo_r_id_o;
    end
    assign axi_rsp_o.r_valid = axi_rsp_i.r_valid;
    assign axi_req_o.r_ready = axi_req_i.r_ready;
  end else begin : gen_bypass_r_channel
    // Bypass
    assign axi_rsp_o.r       = axi_rsp_i.r;
    assign axi_rsp_o.r_valid = axi_rsp_i.r_valid;
    assign axi_req_o.r_ready = axi_req_i.r_ready;
  end

  ////////////////
  // AW channel //
  ////////////////

  if (AxiWriteFlattenEnable) begin : gen_id_flatten_aw_channel
    // Buffer AWID
    assign fifo_aw_id_i = axi_req_i.aw.id;

    // Buffer only when handshake condition is satisfied
    assign fifo_aw_id_push = axi_req_o.aw_valid && axi_rsp_i.aw_ready;

    // Read a new AWID after the previous burst terminates
    assign fifo_aw_id_pop = axi_rsp_o.b_valid && axi_req_i.b_ready;

    fifo_v3 #(
        .FALL_THROUGH(1'b1),
        .DEPTH       (MaxTxns),
        .dtype       (fifo_data_t)
    ) i_awid_fifo (
        .clk_i,
        .rst_ni,
        .flush_i   (1'b0),
        .testmode_i(test_enable_i),
        .full_o    (fifo_aw_id_full),
        .empty_o   (),
        .usage_o   (),
        .data_i    (fifo_aw_id_i),
        .push_i    (fifo_aw_id_push),
        .data_o    (fifo_aw_id_o),
        .pop_i     (fifo_aw_id_pop)
    );

    // Output interface with flattened AWID
    always_comb begin
      `__AXI_TO_AW(, axi_req_o.aw, ., axi_req_i.aw, .)
      axi_req_o.aw.id = AxiWriteIdValue;
    end
    assign axi_req_o.aw_valid = axi_req_i.aw_valid && !fifo_aw_id_full;
    assign axi_rsp_o.aw_ready = axi_rsp_i.aw_ready && !fifo_aw_id_full;

  end else begin : gen_bypass_aw_channel
    // Bypass
    assign axi_req_o.aw = axi_req_i.aw;
    assign axi_req_o.aw_valid = axi_req_i.aw_valid;
    assign axi_rsp_o.aw_ready = axi_rsp_i.aw_ready;
  end

  ///////////////
  // W channel //
  ///////////////

  // Bypass
  assign axi_req_o.w = axi_req_i.w;
  assign axi_req_o.w_valid = axi_req_i.w_valid;
  assign axi_rsp_o.w_ready = axi_rsp_i.w_ready;

  ///////////////
  // B channel //
  ///////////////

  if (AxiWriteFlattenEnable) begin : gen_id_flatten_b_channel
    // Read original AWID from FIFO
    always_comb begin
      `__AXI_TO_B(, axi_rsp_o.b, ., axi_rsp_i.b, .)
      axi_rsp_o.b.id = fifo_aw_id_o;
    end
    assign axi_rsp_o.b_valid = axi_rsp_i.b_valid;
    assign axi_req_o.b_ready = axi_req_i.b_ready;
  end else begin : gen_bypass_b_channel
    // Bypass
    assign axi_rsp_o.b       = axi_rsp_i.b;
    assign axi_rsp_o.b_valid = axi_rsp_i.b_valid;
    assign axi_req_o.b_ready = axi_req_i.b_ready;
  end

endmodule
