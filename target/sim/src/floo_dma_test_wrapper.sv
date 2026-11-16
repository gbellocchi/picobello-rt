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
    parameter int unsigned FlooDmaIndex = '0,
    parameter logic [floo_picobello_noc_pkg::AxiCfgW.AddrWidth-1:0] FlooDmaMemBaseAddr = 32'h0,
    // AXI4 parameters
    parameter floo_pkg::axi_cfg_t AxiCfg = '{default:0},
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
    // AXI4 traffic
    output axi_out_req_t axi_out_req_o,
    input axi_out_rsp_t axi_out_rsp_i,
    // Register bus control
    input reg_req_t regbus_ctrl_regfile_req,
    output reg_rsp_t regbus_ctrl_regfile_rsp
);
    // Register interface
    floo_dma_reg_pkg::floo_dma_reg2hw_t reg2hw_ctrl;
    floo_dma_reg_pkg::floo_dma_hw2reg_t hw2reg_ctrl;

    // DMA controls
    logic dma_start;
    logic dma_done;

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
        .start_of_sim_i ( dma_start                 ),
        .end_of_sim_o   ( dma_done                  )
    );

    // Control register file: start the job list, report its completion. Whether a
    // transfer reads or writes is set per job by the traffic file.
    floo_dma_reg_top #(
        .reg_req_t ( reg_req_t ),
        .reg_rsp_t ( reg_rsp_t )
    ) i_reg_top_ctrl (
        .clk_i,
        .rst_ni,
        .reg_req_i  ( regbus_ctrl_regfile_req ),
        .reg_rsp_o  ( regbus_ctrl_regfile_rsp ),
        .reg2hw     ( reg2hw_ctrl             ),
        .hw2reg     ( hw2reg_ctrl             ),
        .devmode_i  ( 1'b1                    )
    );

    assign dma_start = reg2hw_ctrl.start;
    assign hw2reg_ctrl.done = dma_done;
endmodule
