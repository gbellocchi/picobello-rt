// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "common_cells/registers.svh"
`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_delay #(
  /// AXI bus configuration
  parameter floo_pkg::axi_cfg_t AxiCfg = '0,
  /// Delay value to model memory access cost (in clock cycles)
  parameter int unsigned DelayInput = 0, // Ck
  /// AXI ID flattening enable
  parameter bit ArIdFlatteningEnable = 1'b1,
  parameter int unsigned ArIdFlatteningValue = '0,
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

  // AR shift register
  logic [DelayInput-1:0] ar_valid_shift; // AR valid
  axi_ar_chan_t [DelayInput-1:0] ar_payload_shift; // AR payload
  logic [DelayInput-1:0] ar_shift_en; // Shift enable

  //////////////////
  // AXI AR Delay //
  //////////////////

  // Delay AR channel
  if(DelayInput > 0) begin : gen_delay_ar_channel
    
    // Shift enable is computed backwards from output to input
    // Last stage shifts when downstream memory is ready or if there is a bubble 
    assign ar_shift_en[DelayInput-1] = axi_rsp_i.ar_ready | ~ar_valid_shift[DelayInput-1];
    
    // Compute shift enables for intermediate stages
    if (DelayInput > 1) begin : gen_multi_stage
      for (genvar i = DelayInput-2; i >= 0; i--) begin : gen_shift_en
        // Intermediate stage shifts when next stage shifts or if there is a bubble
        assign ar_shift_en[i] = ar_shift_en[i+1] | ~ar_valid_shift[i];
      end
    end
    
    // Shift register for AR valid signals
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        ar_valid_shift <= '0;
      end else begin
        // Each stage shifts independently when its shift_en is active
        if (ar_shift_en[0]) begin
          ar_valid_shift[0] <= axi_req_i.ar_valid;
        end
        for (int i = 1; i < DelayInput; i++) begin
          if (ar_shift_en[i]) begin
            ar_valid_shift[i] <= ar_valid_shift[i-1];
          end
        end
      end
    end
    
    // Shift register for AR payloads
    always_ff @(posedge clk_i) begin
      // Payload shifts when corresponding valid shifts
      if (ar_shift_en[0]) begin
        ar_payload_shift[0] <= axi_req_i.ar;
      end
      for (int i = 1; i < DelayInput; i++) begin
        if (ar_shift_en[i]) begin
          ar_payload_shift[i] <= ar_payload_shift[i-1];
        end
      end
    end
    
    // Input ready when first stage can accept
    assign axi_rsp_o.ar_ready = ar_shift_en[0];
    
    // Route delayed AR valid
    assign axi_req_o.ar_valid = ar_valid_shift[DelayInput-1];
    
    // Route delayed AR channel
    always_comb begin
      `__AXI_TO_AR(, axi_req_o.ar, ., ar_payload_shift[DelayInput-1], .)
      axi_req_o.ar.id = ArIdFlatteningValue;
      if (ArIdFlatteningEnable) begin
        axi_req_o.ar.id = ArIdFlatteningValue;
      end
    end

  end else begin : gen_bypass_ar_channel
    always_comb begin
      `__AXI_TO_AR(, axi_req_o.ar, ., axi_req_i.ar, .)
      axi_req_o.ar.id = ArIdFlatteningValue;
      if (ArIdFlatteningEnable) begin
        axi_req_o.ar.id = ArIdFlatteningValue;
      end
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