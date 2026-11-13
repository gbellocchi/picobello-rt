// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module floo_dma_test_wrapper 
    import floo_pkg::*;
    import floo_picobello_noc_pkg::*;
    import picobello_pkg::*;
#(
    parameter int unsigned NumPending = 32'd0,
    parameter id_t Id = '0,
    parameter int unsigned FlooDmaIndex = '0,
    parameter logic [floo_picobello_noc_pkg::AxiCfgW.AddrWidth-1:0] FlooDmaMemBaseAddr = 32'h0,
    // AXI4 parameters
    parameter floo_pkg::axi_cfg_t AxiCfg = '{default:0},
    parameter int unsigned AxiLock = 1,
    // AXI4 types
    parameter type axi_in_req_t = logic,
    parameter type axi_in_rsp_t = logic,
    parameter type axi_out_req_t = logic,
    parameter type axi_out_rsp_t = logic,
    // Register bus types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,
    // AXI4 wide payload
    input axi_in_req_t axi_in_req_i,
    output axi_in_rsp_t axi_in_rsp_o,
    output axi_out_req_t axi_out_req_o,
    input axi_out_rsp_t axi_out_rsp_i,
    // Register bus control
    input reg_req_t regbus_read_regfile_req,
    output reg_rsp_t regbus_read_regfile_rsp,
    input reg_req_t regbus_write_regfile_req,
    output reg_rsp_t regbus_write_regfile_rsp,
    input reg_req_t regbus_compute_regfile_req,
    output reg_rsp_t regbus_compute_regfile_rsp
);
    // Register interfaces
    floo_dma_reg_pkg::floo_dma_reg2hw_t reg2hw_read;
    floo_dma_reg_pkg::floo_dma_hw2reg_t hw2reg_read;
    floo_dma_reg_pkg::floo_dma_reg2hw_t reg2hw_write;
    floo_dma_reg_pkg::floo_dma_hw2reg_t hw2reg_write;
    floo_dma_reg_pkg::floo_dma_reg2hw_t reg2hw_compute;
    floo_dma_reg_pkg::floo_dma_hw2reg_t hw2reg_compute;

    // DMA controls
    logic traffic_gen_generic_start;
    logic traffic_gen_generic_done;
    logic read_start;
    logic read_done;
    logic write_start;
    logic write_done;
    logic compute_start;
    logic compute_done;

    // Traffic generator
    floo_dma_test_node #(
        .TA             ( sim_picobello_pkg::ApplTime                ),
        .TT             ( sim_picobello_pkg::TestTime                ),
        .AxiCfg         ( AxiCfg                                     ),
        .MemBaseAddr    ( FlooDmaMemBaseAddr                         ),
        .MemSize        ( picobello_pkg::ClusterTileSize             ),
        .NumAxInFlight  ( picobello_pkg::ChimneyClusterCfg.MaxTxns ),
        .BufferDepth    ( picobello_pkg::ChimneyClusterCfg.MaxTxns ),
        .axi_in_req_t   ( axi_in_req_t                               ),
        .axi_in_rsp_t   ( axi_in_rsp_t                               ),
        .axi_out_req_t  ( axi_out_req_t                              ),
        .axi_out_rsp_t  ( axi_out_rsp_t                              ),
        .JobId          ( FlooDmaIndex                               ),
        .SlaveType      ( floo_test_pkg::IdealSlave                  )
    ) i_dma_node (
        .clk_i          ( clk_i                        ),
        .rst_ni         ( rst_ni                       ),
        .axi_in_req_i   ( '0                           ),
        .axi_in_rsp_o   (                              ),
        .axi_out_req_o  ( axi_out_req_o             ),
        .axi_out_rsp_i  ( axi_out_rsp_i             ),
        .start_of_sim_i ( traffic_gen_generic_start ),
        .end_of_sim_o   ( traffic_gen_generic_done  )
    );

    assign traffic_gen_generic_start = read_start | write_start;
    assign read_done = traffic_gen_generic_done;
    assign write_done = traffic_gen_generic_done;

    // Register file for read transactions
    floo_dma_reg_top #(
        .reg_req_t ( reg_req_t ),
        .reg_rsp_t ( reg_rsp_t )
    ) i_reg_top_read (
        .clk_i,
        .rst_ni,
        .reg_req_i  ( regbus_read_regfile_req ),
        .reg_rsp_o  ( regbus_read_regfile_rsp ),
        .reg2hw     ( reg2hw_read             ),
        .hw2reg     ( hw2reg_read             ),
        .devmode_i  ( 1'b1                       )
    );

    assign read_start = reg2hw_read.start;
    assign hw2reg_read.done = read_done;

    // Register file for write transactions
    floo_dma_reg_top #(
        .reg_req_t ( reg_req_t ),
        .reg_rsp_t ( reg_rsp_t )
    ) i_reg_top_write (
        .clk_i,
        .rst_ni,
        .reg_req_i  ( regbus_write_regfile_req ),
        .reg_rsp_o  ( regbus_write_regfile_rsp ),
        .reg2hw     ( reg2hw_write             ),
        .hw2reg     ( hw2reg_write             ),
        .devmode_i  ( 1'b1                       )
    );

    assign write_start = reg2hw_write.start;
    assign hw2reg_write.done = write_done;

    // Register file for compute operations
    floo_dma_reg_top #(
        .reg_req_t ( reg_req_t ),
        .reg_rsp_t ( reg_rsp_t )
    ) i_reg_top_compute (
        .clk_i,
        .rst_ni,
        .reg_req_i  ( regbus_compute_regfile_req ),
        .reg_rsp_o  ( regbus_compute_regfile_rsp ),
        .reg2hw     ( reg2hw_compute             ),
        .hw2reg     ( hw2reg_compute             ),
        .devmode_i  ( 1'b1                       )
    );

    assign compute_start = reg2hw_compute.start;
    assign hw2reg_compute.done = compute_done;
endmodule
