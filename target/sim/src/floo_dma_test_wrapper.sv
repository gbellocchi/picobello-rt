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
    import fpga_picobello_pkg::*;
#(
    // Traffic generator
    parameter int unsigned NumDmas = 1,
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
    input axi_in_req_t [NumDmas-1:0] axi_in_req_i,
    output axi_in_rsp_t [NumDmas-1:0] axi_in_rsp_o,
    output axi_out_req_t [NumDmas-1:0] axi_out_req_o,
    input axi_out_rsp_t [NumDmas-1:0] axi_out_rsp_i,
    // Register bus control
    input reg_req_t [NumDmas-1:0] regbus_read_regfile_req,
    output reg_rsp_t [NumDmas-1:0] regbus_read_regfile_rsp,
    input reg_req_t [NumDmas-1:0] regbus_write_regfile_req,
    output reg_rsp_t [NumDmas-1:0] regbus_write_regfile_rsp,
    input reg_req_t [NumDmas-1:0] regbus_compute_regfile_req,
    output reg_rsp_t [NumDmas-1:0] regbus_compute_regfile_rsp
);
    // Register interfaces
    floo_dma_reg_pkg::floo_dma_reg2hw_t [NumDmas-1:0] reg2hw_read;
    floo_dma_reg_pkg::floo_dma_hw2reg_t [NumDmas-1:0] hw2reg_read;
    floo_dma_reg_pkg::floo_dma_reg2hw_t [NumDmas-1:0] reg2hw_write;
    floo_dma_reg_pkg::floo_dma_hw2reg_t [NumDmas-1:0] hw2reg_write;
    floo_dma_reg_pkg::floo_dma_reg2hw_t [NumDmas-1:0] reg2hw_compute;
    floo_dma_reg_pkg::floo_dma_hw2reg_t [NumDmas-1:0] hw2reg_compute;

    // DMA controls
    logic [NumDmas-1:0] traffic_gen_generic_start;
    logic [NumDmas-1:0] traffic_gen_generic_done;
    logic [NumDmas-1:0] read_start;
    logic [NumDmas-1:0] read_done;
    logic [NumDmas-1:0] write_start;
    logic [NumDmas-1:0] write_done;
    logic [NumDmas-1:0] compute_start;
    logic [NumDmas-1:0] compute_done;

    for (genvar i = 0; i < NumDmas; i++) begin : gen_traffic_generators

        // Traffic generator
        floo_dma_test_node #(
            .TA             ( sim_picobello_pkg::ApplTime                ),
            .TT             ( sim_picobello_pkg::TestTime                ),
            .AxiCfg         ( AxiCfg                                     ),
            .MemBaseAddr    ( FlooDmaMemBaseAddr                         ),
            .MemSize        ( picobello_pkg::ClusterTileSize             ),
            .NumAxInFlight  ( picobello_pkg::ChimneyClusterRtCfg.MaxTxns ),
            .BufferDepth    ( picobello_pkg::ChimneyClusterRtCfg.MaxTxns ),
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
            .axi_out_req_o  ( axi_out_req_o[i]             ),
            .axi_out_rsp_i  ( axi_out_rsp_i[i]             ),
            .start_of_sim_i ( traffic_gen_generic_start[i] ),
            .end_of_sim_o   ( traffic_gen_generic_done[i]  )
        );

        assign traffic_gen_generic_start[i] = read_start[i] | write_start[i];
        assign read_done[i] = traffic_gen_generic_done[i];
        assign write_done[i] = traffic_gen_generic_done[i];

        // Register file for read transactions
        floo_dma_reg_top #(
            .reg_req_t ( reg_req_t ),
            .reg_rsp_t ( reg_rsp_t )
        ) i_reg_top_read (
            .clk_i,
            .rst_ni,
            .reg_req_i  ( regbus_read_regfile_req[i] ),
            .reg_rsp_o  ( regbus_read_regfile_rsp[i] ),
            .reg2hw     ( reg2hw_read[i]             ),
            .hw2reg     ( hw2reg_read[i]             ),
            .devmode_i  ( 1'b1                       )
        );

        assign read_start[i] = reg2hw_read[i].start;
        assign hw2reg_read[i].done = read_done[i];

        // Register file for write transactions
        floo_dma_reg_top #(
            .reg_req_t ( reg_req_t ),
            .reg_rsp_t ( reg_rsp_t )
        ) i_reg_top_write (
            .clk_i,
            .rst_ni,
            .reg_req_i  ( regbus_write_regfile_req[i] ),
            .reg_rsp_o  ( regbus_write_regfile_rsp[i] ),
            .reg2hw     ( reg2hw_write[i]             ),
            .hw2reg     ( hw2reg_write[i]             ),
            .devmode_i  ( 1'b1                       )
        );

        assign write_start[i] = reg2hw_write[i].start;
        assign hw2reg_write[i].done = write_done[i];

        // Register file for compute operations
        floo_dma_reg_top #(
            .reg_req_t ( reg_req_t ),
            .reg_rsp_t ( reg_rsp_t )
        ) i_reg_top_compute (
            .clk_i,
            .rst_ni,
            .reg_req_i  ( regbus_compute_regfile_req[i] ),
            .reg_rsp_o  ( regbus_compute_regfile_rsp[i] ),
            .reg2hw     ( reg2hw_compute[i]             ),
            .hw2reg     ( hw2reg_compute[i]             ),
            .devmode_i  ( 1'b1                       )
        );

        assign compute_start[i] = reg2hw_compute[i].start;
        assign hw2reg_compute[i].done = compute_done[i];
    end
endmodule
