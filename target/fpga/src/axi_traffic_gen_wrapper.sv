// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_traffic_gen_wrapper 
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
    // AXI4-Lite parameters
    parameter floo_pkg::axi_cfg_t AxiLiteCfg = '{default:0},
    // AXI4 types
    parameter type axi_in_req_t = logic,
    parameter type axi_in_rsp_t = logic,
    parameter type axi_out_req_t = logic,
    parameter type axi_out_rsp_t = logic,
    // AXI4-Lite types
    parameter type axi_lite_req_t = logic,
    parameter type axi_lite_rsp_t = logic,
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
    // AXI4-Lite control
    input axi_lite_host_req_t [NumDmas-1:0] axi_lite_read_regfile_req,
    output axi_lite_host_rsp_t [NumDmas-1:0] axi_lite_read_regfile_rsp,
    input axi_lite_host_req_t [NumDmas-1:0] axi_lite_write_regfile_req,
    output axi_lite_host_rsp_t [NumDmas-1:0] axi_lite_write_regfile_rsp,
    input axi_lite_host_req_t [NumDmas-1:0] axi_lite_compute_regfile_req,
    output axi_lite_host_rsp_t [NumDmas-1:0] axi_lite_compute_regfile_rsp
);  
    // AXI4 interfaces
    AXI_BUS #(
        .AXI_ADDR_WIDTH (AxiCfg.AddrWidth),
        .AXI_DATA_WIDTH (AxiCfg.DataWidth),
        .AXI_ID_WIDTH   (AxiCfg.OutIdWidth),
        .AXI_USER_WIDTH (AxiCfg.UserWidth)
    ) traffic_gen_wide_out [NumDmas-1:0]();

    axi_out_req_t [NumDmas-1:0] axi_traffic_gen_req;
    axi_out_rsp_t [NumDmas-1:0] axi_traffic_gen_rsp;

    // AXI4-Lite interfaces
    AXI_LITE #(
        .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
        .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
    ) traffic_gen_read_regfile [NumDmas-1:0]();

    AXI_LITE #(
        .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
        .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
    ) traffic_gen_write_regfile [NumDmas-1:0]();

    AXI_LITE #(
        .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
        .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
    ) traffic_gen_compute_regfile [NumDmas-1:0]();

    // Register bus interfaces
    reg_req_t [NumDmas-1:0] regbus_read_regfile_req; 
    reg_rsp_t [NumDmas-1:0] regbus_read_regfile_rsp;
    reg_req_t [NumDmas-1:0] regbus_write_regfile_req; 
    reg_rsp_t [NumDmas-1:0] regbus_write_regfile_rsp;
    reg_req_t [NumDmas-1:0] regbus_compute_regfile_req; 
    reg_rsp_t [NumDmas-1:0] regbus_compute_regfile_rsp;

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
        if (fpga_picobello_pkg::UseHlsTg == 1'b1) begin: gen_hls_dma

            // Traffic generator
            axi_hls_tg_rw_wrapper #(
                .AxiAddrWidth       (AxiCfg.AddrWidth),
                .AxiDataWidth       (AxiCfg.DataWidth),
                .AxiIdWidth         (AxiCfg.OutIdWidth),
                .AxiUserWidth       (AxiCfg.UserWidth),
                .AxiLock            (1),
                .AxiLiteAddrWidth   (AxiLiteCfg.AddrWidth),
                .AxiLiteDataWidth   (AxiLiteCfg.DataWidth)
            ) i_axi_hls_tg_wrapper (
                .clk_i                      (clk_i),
                .rst_ni                     (rst_ni),
                .axi_tg_wide_out            (traffic_gen_wide_out[i]),
                .axi_lite_read_regfile      (traffic_gen_read_regfile[i]),
                .axi_lite_write_regfile     (traffic_gen_write_regfile[i]),
                .axi_lite_compute_regfile   (traffic_gen_compute_regfile[i])
            );

            // Bind to AXI4 wide interfaces
            `AXI_ASSIGN_TO_REQ(axi_out_req_o[i], traffic_gen_wide_out[i])
            `AXI_ASSIGN_FROM_RESP(traffic_gen_wide_out[i], axi_out_rsp_i[i])

            // Bind to AXI4-Lite interfaces
            `AXI_LITE_ASSIGN_FROM_REQ(traffic_gen_read_regfile[i], axi_lite_read_regfile_req[i])
            `AXI_LITE_ASSIGN_TO_RESP(axi_lite_read_regfile_rsp[i], traffic_gen_read_regfile[i])
            `AXI_LITE_ASSIGN_FROM_REQ(traffic_gen_write_regfile[i], axi_lite_write_regfile_req[i])
            `AXI_LITE_ASSIGN_TO_RESP(axi_lite_write_regfile_rsp[i], traffic_gen_write_regfile[i])
            `AXI_LITE_ASSIGN_FROM_REQ(traffic_gen_compute_regfile[i], axi_lite_compute_regfile_req[i])
            `AXI_LITE_ASSIGN_TO_RESP(axi_lite_compute_regfile_rsp[i], traffic_gen_compute_regfile[i])

        end else begin: gen_floo_dma

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
            axi_lite_to_reg #(
                .ADDR_WIDTH     ( AxiLiteCfg.AddrWidth ),
                .DATA_WIDTH     ( AxiLiteCfg.DataWidth ),
                .BUFFER_DEPTH   ( 2                    ),
                .DECOUPLE_W     ( 1                    ),
                .axi_lite_req_t ( axi_lite_req_t       ),
                .axi_lite_rsp_t ( axi_lite_rsp_t       ),
                .reg_req_t      ( reg_req_t            ),
                .reg_rsp_t      ( reg_rsp_t            )
            ) i_axi_lite_to_reg_read (
                .clk_i,
                .rst_ni,
                .axi_lite_req_i ( axi_lite_read_regfile_req[i] ),
                .axi_lite_rsp_o ( axi_lite_read_regfile_rsp[i] ),
                .reg_req_o      ( regbus_read_regfile_req[i]   ),
                .reg_rsp_i      ( regbus_read_regfile_rsp[i]   )
            );
            
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
            axi_lite_to_reg #(
                .ADDR_WIDTH     ( AxiLiteCfg.AddrWidth ),
                .DATA_WIDTH     ( AxiLiteCfg.DataWidth ),
                .BUFFER_DEPTH   ( 2                    ),
                .DECOUPLE_W     ( 1                    ),
                .axi_lite_req_t ( axi_lite_req_t       ),
                .axi_lite_rsp_t ( axi_lite_rsp_t       ),
                .reg_req_t      ( reg_req_t            ),
                .reg_rsp_t      ( reg_rsp_t            )
            ) i_axi_lite_to_reg_write (
                .clk_i,
                .rst_ni,
                .axi_lite_req_i ( axi_lite_write_regfile_req[i] ),
                .axi_lite_rsp_o ( axi_lite_write_regfile_rsp[i] ),
                .reg_req_o      ( regbus_write_regfile_req[i]   ),
                .reg_rsp_i      ( regbus_write_regfile_rsp[i]   )
            );
            
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

            // Register file for compute transactions
            axi_lite_to_reg #(
                .ADDR_WIDTH     ( AxiLiteCfg.AddrWidth ),
                .DATA_WIDTH     ( AxiLiteCfg.DataWidth ),
                .BUFFER_DEPTH   ( 2                    ),
                .DECOUPLE_W     ( 1                    ),
                .axi_lite_req_t ( axi_lite_req_t       ),
                .axi_lite_rsp_t ( axi_lite_rsp_t       ),
                .reg_req_t      ( reg_req_t            ),
                .reg_rsp_t      ( reg_rsp_t            )
            ) i_axi_lite_to_reg_compute (
                .clk_i,
                .rst_ni,
                .axi_lite_req_i ( axi_lite_compute_regfile_req[i] ),
                .axi_lite_rsp_o ( axi_lite_compute_regfile_rsp[i] ),
                .reg_req_o      ( regbus_compute_regfile_req[i]   ),
                .reg_rsp_i      ( regbus_compute_regfile_rsp[i]   )
            );
            
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
    end
endmodule
