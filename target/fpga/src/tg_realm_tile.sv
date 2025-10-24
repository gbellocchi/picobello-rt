// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module cluster_rt_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
  import fpga_picobello_pkg::*;
#(
  /// Number of cores in the tile.
  parameter int unsigned NumCores = 1,
  parameter int unsigned NumCoresMax = 64
) (
  input  logic                                    clk_i,
  input  logic                                    rst_ni,
  input  logic                                    test_enable_i,
  // Traffic generator ports
  input  axi_wide_in_addr_t                       base_addr_i,
  // Chimney ports
  input  id_t                                     id_i,
  // Router ports
  output floo_req_t                 [ West:North] floo_req_o,
  input  floo_rsp_t                 [ West:North] floo_rsp_i,
  output floo_wide_t                [ West:North] floo_wide_o,
  input  floo_req_t                 [ West:North] floo_req_i,
  output floo_rsp_t                 [ West:North] floo_rsp_o,
  input  floo_wide_t                [ West:North] floo_wide_i
);

  ////////////
  // Router //
  ////////////

  floo_req_t [Eject:North] router_floo_req_out, router_floo_req_in;
  floo_rsp_t [Eject:North] router_floo_rsp_out, router_floo_rsp_in;
  floo_wide_t [Eject:North] router_floo_wide_out, router_floo_wide_in;

  floo_nw_router #(
    .AxiCfgN     (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW     (floo_picobello_noc_pkg::AxiCfgW),
    .RouteAlgo   (floo_picobello_noc_pkg::RouteCfg.RouteAlgo),
    .NumRoutes   (5),
    .InFifoDepth (2),
    .OutFifoDepth(2),
    .id_t        (floo_picobello_noc_pkg::id_t),
    .hdr_t       (floo_picobello_noc_pkg::hdr_t),
    .floo_req_t  (floo_req_t),
    .floo_rsp_t  (floo_rsp_t),
    .floo_wide_t (floo_wide_t)
  ) i_router (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .id_route_map_i('0),
    .floo_req_i    (router_floo_req_in),
    .floo_rsp_o    (router_floo_rsp_out),
    .floo_req_o    (router_floo_req_out),
    .floo_rsp_i    (router_floo_rsp_in),
    .floo_wide_i   (router_floo_wide_in),
    .floo_wide_o   (router_floo_wide_out)
  );

  assign floo_req_o                      = router_floo_req_out[West:North];
  assign router_floo_req_in[West:North]  = floo_req_i;
  assign floo_rsp_o                      = router_floo_rsp_out[West:North];
  assign router_floo_rsp_in[West:North]  = floo_rsp_i;
  assign floo_wide_o                     = router_floo_wide_out[West:North];
  assign router_floo_wide_in[West:North] = floo_wide_i;

  /////////////
  // Chimney //
  /////////////

  floo_picobello_noc_pkg::axi_narrow_in_req_t chimney_narrow_in_req;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t chimney_narrow_in_rsp;
  floo_picobello_noc_pkg::axi_narrow_out_req_t chimney_narrow_out_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t chimney_narrow_out_rsp;
  floo_picobello_noc_pkg::axi_wide_in_req_t chimney_wide_in_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t chimney_wide_in_rsp;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) chimney_narrow_out[0:0]();

  localparam chimney_cfg_t ChimneyCfgN = set_ports(ChimneyDefaultCfg, 1'b1, 1'b0);
  localparam chimney_cfg_t ChimneyCfgW = set_ports(ChimneyDefaultCfg, 1'b0, 1'b1);

  floo_nw_chimney #(
    .AxiCfgN             (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW             (floo_picobello_noc_pkg::AxiCfgW),
    .ChimneyCfgN         (ChimneyCfgN),
    .ChimneyCfgW         (ChimneyCfgW),
    .RouteCfg            (floo_picobello_noc_pkg::RouteCfg),
    .AtopSupport         (1'b1),
    .MaxAtomicTxns       (1),
    .Sam                 (floo_picobello_noc_pkg::Sam),
    .id_t                (floo_picobello_noc_pkg::id_t),
    .rob_idx_t           (floo_picobello_noc_pkg::rob_idx_t),
    .hdr_t               (floo_picobello_noc_pkg::hdr_t),
    .sam_rule_t          (floo_picobello_noc_pkg::sam_rule_t),
    .axi_narrow_in_req_t (floo_picobello_noc_pkg::axi_narrow_in_req_t),
    .axi_narrow_in_rsp_t (floo_picobello_noc_pkg::axi_narrow_in_rsp_t),
    .axi_narrow_out_req_t(floo_picobello_noc_pkg::axi_narrow_out_req_t),
    .axi_narrow_out_rsp_t(floo_picobello_noc_pkg::axi_narrow_out_rsp_t),
    .axi_wide_in_req_t   (floo_picobello_noc_pkg::axi_wide_in_req_t),
    .axi_wide_in_rsp_t   (floo_picobello_noc_pkg::axi_wide_in_rsp_t),
    .axi_wide_out_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
    .axi_wide_out_rsp_t  (floo_picobello_noc_pkg::axi_wide_out_rsp_t),
    .floo_req_t          (floo_picobello_noc_pkg::floo_req_t),
    .floo_rsp_t          (floo_picobello_noc_pkg::floo_rsp_t),
    .floo_wide_t         (floo_picobello_noc_pkg::floo_wide_t)
  ) i_chimney (
    .clk_i,
    .rst_ni,
    .test_enable_i,
    .id_i,
    .route_table_i       ('0),
    .sram_cfg_i          ('0),
    .axi_narrow_in_req_i ('0),
    .axi_narrow_in_rsp_o (),
    .axi_narrow_out_req_o(chimney_narrow_out_req),
    .axi_narrow_out_rsp_i(chimney_narrow_out_rsp),
    .axi_wide_in_req_i   (chimney_wide_in_req),
    .axi_wide_in_rsp_o   (chimney_wide_in_rsp),
    .axi_wide_out_req_o  (),
    .axi_wide_out_rsp_i  ('0),
    .floo_req_o          (router_floo_req_in[Eject]),
    .floo_rsp_o          (router_floo_rsp_in[Eject]),
    .floo_wide_o         (router_floo_wide_in[Eject]),
    .floo_req_i          (router_floo_req_out[Eject]),
    .floo_rsp_i          (router_floo_rsp_out[Eject]),
    .floo_wide_i         (router_floo_wide_out[Eject])
  );

  `AXI_ASSIGN_FROM_REQ(chimney_narrow_out[0], chimney_narrow_out_req)
  `AXI_ASSIGN_TO_RESP(chimney_narrow_out_rsp, chimney_narrow_out[0])

  //////////////////////////////////////////////////////////////
  // AXI4 narrow chimney => AXI4 narrow cores (configuration) //
  //////////////////////////////////////////////////////////////

  // Each narrow NI output is routed toward a specific core for configuration

  // Core address map
  axi_narrow_out_addr_downsized_addr_t core_addr_space_dim = 32'h0000_1000; // Max number of addressable masters = 64
  axi_narrow_out_addr_downsized_addr_t many_core_addr_space_dim = core_addr_space_dim * NumCores;

  // Address map
  axi_pkg::xbar_rule_64_t [NumCores-1:0] ni2cores_addr_map;

  localparam axi_pkg::xbar_cfg_t XbarCfgNi2Cores = '{
    NoSlvPorts:         1, // Thus no ID expansion for outputs
    NoMstPorts:         NumCores,
    MaxMstTrans:        1,
    MaxSlvTrans:        1,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth,
    AxiIdUsedSlvPorts:  1,
    UniqueIds:          0,
    AxiAddrWidth:       floo_picobello_noc_pkg::AxiCfgN.AddrWidth,
    AxiDataWidth:       floo_picobello_noc_pkg::AxiCfgN.DataWidth,
    NoAddrRules:        NumCores
  };

  // AXI4 multi-core
  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) axi_core [NumCores-1:0]();

  // Address map
  for (genvar i = 0; i < NumCores; i++) begin : gen_rt_tile_ni2cores_addr_map
    assign ni2cores_addr_map[i] = '{
      idx:        i,
      start_addr: base_addr_i + i * core_addr_space_dim,
      end_addr:   base_addr_i + (i + 1) * core_addr_space_dim
    };
  end

  axi_xbar_intf #(
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
    .Cfg            (XbarCfgNi2Cores),
    .ATOPS          (1'b0),
    .rule_t         (axi_pkg::xbar_rule_64_t)
  ) i_rt_tile_ni2cores_xbar (
    .clk_i,
    .rst_ni,
    .test_i                 (1'b0),
    .slv_ports              (chimney_narrow_out),
    .mst_ports              (axi_core),
    .addr_map_i             (ni2cores_addr_map),
    .en_default_mst_port_i  ('0),
    .default_mst_port_i     ('0)
  );

  ///////////////////////////////////////////////////
  // AXI4 narrow cores => AXI4 core register files //
  ///////////////////////////////////////////////////

  // Each core can be configured independently accessing the following registers:
  // - Traffic generator read configuration (from the Host processor)
  // - Traffic generator write configuration (from the Host processor)
  // - Traffic generator compute configuration (from the Host processor)
  // - AXI-Realm wide port configuration (from the Host processor)

  localparam int unsigned NumCoreRegFiles = 4;

  // Number of address map rules
  localparam int unsigned NumCoreRegFileRules = 3;
  localparam int unsigned NumAxiRealmRules = 1;
  localparam int unsigned NumRulesCore2RegFile = NumCoreRegFileRules + NumAxiRealmRules;

  // Indices
  localparam int unsigned IdxPortAxiRealm   = 0;
  localparam int unsigned IdxPortTgRead     = 1;
  localparam int unsigned IdxPortTgWrite    = 2;
  localparam int unsigned IdxPortTgCompute  = 3;

  // Core register files address map
  axi_narrow_out_addr_downsized_addr_t core_rt_addr_offset = 32'h0000_0000;
  axi_narrow_out_addr_downsized_addr_t core_dma_r_addr_offset = 32'h0000_0800;
  axi_narrow_out_addr_downsized_addr_t core_dma_w_addr_offset = 32'h0000_0830;
  axi_narrow_out_addr_downsized_addr_t core_compute_addr_offset = 32'h0000_0860; // not used
  
  axi_narrow_out_addr_downsized_addr_t core_rt_addr_dim = 32'h0000_0800;
  axi_narrow_out_addr_downsized_addr_t core_dma_r_addr_dim = 32'h0000_0030;
  axi_narrow_out_addr_downsized_addr_t core_dma_w_addr_dim = 32'h0000_0030;
  axi_narrow_out_addr_downsized_addr_t core_compute_addr_dim = 32'h0000_0030; // not used

  // AXI4 core register files
  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) axi_core_regfile [NumCores-1:0][NumCoreRegFiles-1:0]();

  // Address map
  axi_pkg::xbar_rule_64_t [NumRulesCore2RegFile-1:0] core2regfile_addr_map;

  localparam axi_pkg::xbar_cfg_t XbarCfgCore2RegFile = '{
    NoSlvPorts:         1, // Thus no ID expansion for outputs
    NoMstPorts:         NumCoreRegFiles,
    MaxMstTrans:        1,
    MaxSlvTrans:        1,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth,
    AxiIdUsedSlvPorts:  1,
    UniqueIds:          0,
    AxiAddrWidth:       floo_picobello_noc_pkg::AxiCfgN.AddrWidth,
    AxiDataWidth:       floo_picobello_noc_pkg::AxiCfgN.DataWidth,
    NoAddrRules:        NumRulesCore2RegFile
  };

  // AXI-Realm wide configuration
  assign core2regfile_addr_map[0] = '{
    idx:        IdxPortAxiRealm,
    start_addr: base_addr_i + core_rt_addr_offset,
    end_addr:   base_addr_i + core_rt_addr_offset + core_rt_addr_dim
  };

  // Wide read
  assign core2regfile_addr_map[1] = '{
    idx:        IdxPortTgRead,
    start_addr: base_addr_i + core_dma_r_addr_offset,
    end_addr:   base_addr_i + core_dma_r_addr_offset + core_dma_r_addr_dim
  };

  // Wide write
  assign core2regfile_addr_map[2] = '{
    idx:        IdxPortTgWrite,
    start_addr: base_addr_i + core_dma_w_addr_offset,
    end_addr:   base_addr_i + core_dma_w_addr_offset + core_dma_w_addr_dim
  };

  // Timer (compute)
  assign core2regfile_addr_map[3] = '{
    idx:        IdxPortTgCompute,
    start_addr: base_addr_i + core_compute_addr_offset,
    end_addr:   base_addr_i + core_compute_addr_offset + core_compute_addr_dim
  };

  for (genvar i = 0; i < NumCores; i++) begin : gen_rt_tile_core2regfile_xbar
    axi_xbar_intf #(
      .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
      .Cfg            (XbarCfgCore2RegFile),
      .ATOPS          (1'b0),
      .rule_t         (axi_pkg::xbar_rule_64_t)
    ) i_rt_tile_core2regfile_xbar (
      .clk_i,
      .rst_ni,
      .test_i                 (1'b0),
      .slv_ports              (axi_core[i:i]),
      .mst_ports              (axi_core_regfile[i]),
      .addr_map_i             (core2regfile_addr_map),
      .en_default_mst_port_i  ('0),
      .default_mst_port_i     ('0)
    );
  end

  ///////////////////////////////////////////////////////////////
  // AXI4 core register files => AXI4-Lite core register files //
  ///////////////////////////////////////////////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiCfgDataDownsized.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiCfgDataDownsized.DataWidth),
    .AXI_ID_WIDTH   (fpga_picobello_pkg::AxiCfgDataDownsized.OutIdWidth),
    .AXI_USER_WIDTH (fpga_picobello_pkg::AxiCfgDataDownsized.UserWidth)
  ) axi_core_regfile_data_downsized [NumCores-1:0][NumCoreRegFiles-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiCfgAddrDownsized.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth),
    .AXI_ID_WIDTH   (fpga_picobello_pkg::AxiCfgAddrDownsized.OutIdWidth),
    .AXI_USER_WIDTH (fpga_picobello_pkg::AxiCfgAddrDownsized.UserWidth)
  ) axi_core_regfile_addr_downsized [NumCores-1:0][NumCoreRegFiles-1:0]();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiLiteCfg.DataWidth)
  ) axi_lite_core_regfile [NumCores-1:0][NumCoreRegFiles-1:0]();

  axi_lite_host_req_t [NumCores-1:0] axi_lite_read_regfile_req;
  axi_lite_host_rsp_t [NumCores-1:0] axi_lite_read_regfile_rsp;

  axi_lite_host_req_t [NumCores-1:0] axi_lite_write_regfile_req;
  axi_lite_host_rsp_t [NumCores-1:0] axi_lite_write_regfile_rsp;

  axi_lite_host_req_t [NumCores-1:0] axi_lite_comp_regfile_req;
  axi_lite_host_rsp_t [NumCores-1:0] axi_lite_comp_regfile_rsp;

  axi_lite_host_req_t [NumCores-1:0] axi_lite_realm_regfile_req;
  axi_lite_host_rsp_t [NumCores-1:0] axi_lite_realm_regfile_rsp;

  axi_narrow_out_addr_downsized_addr_t axi_core_regfile_addr_downsized_aw_addr [NumCores-1:0][NumCoreRegFiles-1:0];
  axi_narrow_out_addr_downsized_addr_t axi_core_regfile_addr_downsized_ar_addr [NumCores-1:0][NumCoreRegFiles-1:0];

  for (genvar i = 0; i < NumCores; i++) begin : gen_core_regfile_axi_to_axi_lite_i
    for (genvar j = 0; j < NumCoreRegFiles; j++) begin : gen_core_regfile_axi_to_axi_lite_j

      axi_dw_converter_intf #(
        .AXI_ID_WIDTH             (fpga_picobello_pkg::AxiCfgDataDownsized.OutIdWidth),
        .AXI_ADDR_WIDTH           (fpga_picobello_pkg::AxiCfgDataDownsized.AddrWidth),
        .AXI_SLV_PORT_DATA_WIDTH  (fpga_picobello_pkg::AxiCfgDataDownsized.DataWidth),
        .AXI_MST_PORT_DATA_WIDTH  (fpga_picobello_pkg::AxiCfgDataDownsized.DataWidth),
        .AXI_USER_WIDTH           (fpga_picobello_pkg::AxiCfgDataDownsized.UserWidth),
        .AXI_MAX_READS            (8)
      ) i_axi_data_converter_core_regfile (
        .clk_i,
        .rst_ni,
        .slv    (axi_core_regfile[i][j]),
        .mst    (axi_core_regfile_data_downsized[i][j])
      );

      assign axi_core_regfile_addr_downsized_aw_addr[i][j] = axi_core_regfile_data_downsized[i][j].aw_addr[31:0];
      assign axi_core_regfile_addr_downsized_ar_addr[i][j] = axi_core_regfile_data_downsized[i][j].ar_addr[31:0];

      axi_modify_address_intf #(
        .AXI_SLV_PORT_ADDR_WIDTH  (fpga_picobello_pkg::AxiCfgDataDownsized.AddrWidth),
        .AXI_MST_PORT_ADDR_WIDTH  (fpga_picobello_pkg::AxiCfgAddrDownsized.AddrWidth),
        .AXI_DATA_WIDTH           (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth),
        .AXI_ID_WIDTH             (fpga_picobello_pkg::AxiCfgAddrDownsized.OutIdWidth),
        .AXI_USER_WIDTH           (fpga_picobello_pkg::AxiCfgAddrDownsized.UserWidth)
      ) i_axi_addr_converter_core_regfile (
        .slv            (axi_core_regfile_data_downsized[i][j]),
        .mst_aw_addr_i  (axi_core_regfile_addr_downsized_aw_addr[i][j]),
        .mst_ar_addr_i  (axi_core_regfile_addr_downsized_ar_addr[i][j]),
        .mst            (axi_core_regfile_addr_downsized[i][j])
      );

      axi_to_axi_lite_intf #(
        .AXI_ADDR_WIDTH     (fpga_picobello_pkg::AxiCfgAddrDownsized.AddrWidth),
        .AXI_DATA_WIDTH     (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth),
        .AXI_ID_WIDTH       (fpga_picobello_pkg::AxiCfgAddrDownsized.OutIdWidth),
        .AXI_USER_WIDTH     (fpga_picobello_pkg::AxiCfgAddrDownsized.UserWidth),
        .AXI_MAX_WRITE_TXNS (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
        .AXI_MAX_READ_TXNS  (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
        .FALL_THROUGH       (1'b0),
        .FULL_BW            (0)
      ) i_axi_to_axi_lite_core_regfile (
        .clk_i,
        .rst_ni,
        .testmode_i (test_enable_i),
        .slv        (axi_core_regfile_addr_downsized[i][j]),
        .mst        (axi_lite_core_regfile[i][j])
      );
    end

    `AXI_LITE_ASSIGN_TO_REQ(axi_lite_realm_regfile_req[i], axi_lite_core_regfile[i][0])
    `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_core_regfile[i][0], axi_lite_realm_regfile_rsp[i])

    `AXI_LITE_ASSIGN_TO_REQ(axi_lite_read_regfile_req[i], axi_lite_core_regfile[i][1])
    `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_core_regfile[i][1], axi_lite_read_regfile_rsp[i])

    `AXI_LITE_ASSIGN_TO_REQ(axi_lite_write_regfile_req[i], axi_lite_core_regfile[i][2])
    `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_core_regfile[i][2], axi_lite_write_regfile_rsp[i])

    `AXI_LITE_ASSIGN_TO_REQ(axi_lite_comp_regfile_req[i], axi_lite_core_regfile[i][3])
    `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_core_regfile[i][3], axi_lite_comp_regfile_rsp[i])
  end

  ///////////////
  // AXI-Realm //
  ///////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  axi_wide_tg_req_t [NumCores-1:0] axi_realm_in_req;
  axi_wide_tg_rsp_t [NumCores-1:0] axi_realm_in_rsp;
  axi_wide_tg_req_t [NumCores-1:0] axi_realm_out_req;
  axi_wide_tg_rsp_t [NumCores-1:0] axi_realm_out_rsp;

  axi_lite_host_req_t axi_lite_realm_regfile_mux_req;
  axi_lite_host_rsp_t axi_lite_realm_regfile_mux_rsp;

  // Register bus signals
  cfg_req_t regbus_realm_regfile_req; 
  cfg_rsp_t regbus_realm_regfile_rsp;

  // AXI RT IDs
  slv_id_t realm_regfile_id;

  // Mux AXI4-Lite inputs accessing the shared AXI-Realm register file
  axi_lite_mux #(
    .aw_chan_t      (axi_lite_host_aw_chan_t),
    .w_chan_t       (axi_lite_host_w_chan_t),
    .b_chan_t       (axi_lite_host_b_chan_t),
    .ar_chan_t      (axi_lite_host_ar_chan_t),
    .r_chan_t       (axi_lite_host_r_chan_t),
    .axi_req_t      (axi_lite_host_req_t),
    .axi_resp_t     (axi_lite_host_rsp_t),
    .NoSlvPorts     (NumCores),
    .MaxTrans       (1),
    .FallThrough    (1'b0),
    .SpillAw        (1'b1),
    .SpillW         (1'b1),
    .SpillB         (1'b1),
    .SpillAr        (1'b1),
    .SpillR         (1'b1)
  ) i_axi_lite_realm_regfile_mux (
    .clk_i,                
    .rst_ni,              
    .test_i       (1'b0),             
    .slv_reqs_i   (axi_lite_realm_regfile_req),
    .slv_resps_o  (axi_lite_realm_regfile_rsp),
    .mst_req_o    (axi_lite_realm_regfile_mux_req),
    .mst_resp_i   (axi_lite_realm_regfile_mux_rsp)
  );

  // Convert AXI4-Lite to custom register interface for the RT wide configuration bus
  axi_lite_to_reg #(
    .ADDR_WIDTH     (fpga_picobello_pkg::AxiCfgAddrDownsized.AddrWidth),
    .DATA_WIDTH     (fpga_picobello_pkg::AxiCfgAddrDownsized.DataWidth),
    .BUFFER_DEPTH   (2),
    .DECOUPLE_W     (1),
    .axi_lite_req_t (fpga_picobello_pkg::axi_lite_host_req_t),
    .axi_lite_rsp_t (fpga_picobello_pkg::axi_lite_host_rsp_t),
    .reg_req_t      (cfg_req_t),
    .reg_rsp_t      (cfg_rsp_t)
  ) i_axi_lite_to_reg_wide (
    .clk_i,
    .rst_ni,
    .axi_lite_req_i (axi_lite_realm_regfile_mux_req),
    .axi_lite_rsp_o (axi_lite_realm_regfile_mux_rsp),
    .reg_req_o      (regbus_realm_regfile_req),
    .reg_rsp_i      (regbus_realm_regfile_rsp)
  );

  // AXI RT unit wide
  axi_rt_unit_top #(
    .NumManagers      (NumCores),
    .AddrWidth        (fpga_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .DataWidth        (fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .IdWidth          (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .UserWidth        (fpga_picobello_pkg::AxiCfgWTrafficGen.UserWidth),
    .NumPending       (NumPending),
    .WBufferDepth     (WBufferDepth),
    .NumAddrRegions   (NumRegions),
    .BudgetWidth      (BudgetWidth),
    .PeriodWidth      (PeriodWidth),
    .RegIdWidth       (AxiSlvIdWidth),
    .CutDecErrors     (1'b0),
    .CutSplitterPaths (1'b0),
    .aw_chan_t        (axi_wide_tg_aw_chan_t),
    .ar_chan_t        (axi_wide_tg_ar_chan_t),
    .w_chan_t         (axi_wide_tg_w_chan_t),
    .r_chan_t         (axi_wide_tg_r_chan_t),
    .b_chan_t         (axi_wide_tg_b_chan_t),
    .axi_req_t        (axi_wide_tg_req_t),
    .axi_resp_t       (axi_wide_tg_rsp_t),
    .req_req_t        (cfg_req_t),
    .req_rsp_t        (cfg_rsp_t)
  ) i_axi_rt_unit_wide (
    .clk_i,
    .rst_ni,
    .slv_req_i        (axi_realm_in_req),
    .slv_resp_o       (axi_realm_in_rsp),
    .mst_req_o        (axi_realm_out_req),
    .mst_resp_i       (axi_realm_out_rsp), 
    .reg_req_i        (regbus_realm_regfile_req), 
    .reg_rsp_o        (regbus_realm_regfile_rsp), 
    .reg_id_i         (realm_regfile_id)  
  );

  assign realm_regfile_id = id_i.y + MeshDim.y * id_i.x;

  ////////////////////////////////////////////////////
  // AXI4 wide cores (traffic) => AXI4 wide chimney //
  ////////////////////////////////////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .AXI_ID_WIDTH   (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .AXI_USER_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.UserWidth)
  ) axi_realm_out [NumCores-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgW.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgW.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgW.InIdWidth), // Changed from OutIdWidth to InIdWidth
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgW.UserWidth)
  ) axi_realm_out_mux ();

  for (genvar i = 0; i < NumCores; i++) begin : gen_rt_tile_axirt2ni_assign
    `AXI_ASSIGN_FROM_REQ(axi_realm_out[i], axi_realm_out_req[i])
    `AXI_ASSIGN_TO_RESP(axi_realm_out_rsp[i], axi_realm_out[i])
  end

  // Mux AXI4 wide outputs to the FlooNoC NI
  axi_mux_intf #(
    .SLV_AXI_ID_WIDTH   (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth), // traffic generator ID width
    .MST_AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgW.InIdWidth), // expanded, based on NumCores, and matching NI ID width
    .AXI_ADDR_WIDTH     (fpga_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH     (fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .AXI_USER_WIDTH     (fpga_picobello_pkg::AxiCfgWTrafficGen.UserWidth),
    .NO_SLV_PORTS       (NumCores),
    .MAX_W_TRANS        (NumCoresMax),
    .FALL_THROUGH       (1'b0),
    .SPILL_AW           (1'b1),
    .SPILL_W            (1'b1),
    .SPILL_B            (1'b1),
    .SPILL_AR           (1'b1),
    .SPILL_R            (1'b1)
  ) i_axi_wide_out_rt2ni_mux (
    .clk_i,                
    .rst_ni,
    .test_i   (1'b0),
    .slv      (axi_realm_out),
    .mst      (axi_realm_out_mux)
  );

  `AXI_ASSIGN_TO_REQ(chimney_wide_in_req, axi_realm_out_mux)
  `AXI_ASSIGN_FROM_RESP(axi_realm_out_mux, chimney_wide_in_rsp)

  ////////////////////////
  // Traffic generators //
  ////////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .AXI_ID_WIDTH   (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .AXI_USER_WIDTH (fpga_picobello_pkg::AxiCfgWTrafficGen.UserWidth)
  ) cluster_rt_wide_out [NumCores-1:0]();

  // Output data traffic
  axi_wide_tg_req_t [NumCores-1:0] cluster_rt_wide_out_req;
  axi_wide_tg_rsp_t [NumCores-1:0] cluster_rt_wide_out_rsp;

  AXI_LITE #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiLiteCfg.DataWidth)
  ) axi_lite_read_regfile [NumCores-1:0]();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiLiteCfg.DataWidth)
  ) axi_lite_write_regfile [NumCores-1:0]();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (fpga_picobello_pkg::AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (fpga_picobello_pkg::AxiLiteCfg.DataWidth)
  ) axi_lite_comp_regfile [NumCores-1:0]();

  for (genvar i = 0; i < NumCores; i++) begin : gen_core
    `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_read_regfile[i], axi_lite_read_regfile_req[i])
    `AXI_LITE_ASSIGN_TO_RESP(axi_lite_read_regfile_rsp[i], axi_lite_read_regfile[i])

    `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_write_regfile[i], axi_lite_write_regfile_req[i])
    `AXI_LITE_ASSIGN_TO_RESP(axi_lite_write_regfile_rsp[i], axi_lite_write_regfile[i])

    `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_comp_regfile[i], axi_lite_comp_regfile_req[i])
    `AXI_LITE_ASSIGN_TO_RESP(axi_lite_comp_regfile_rsp[i], axi_lite_comp_regfile[i])

    axi_hls_tg_rw_wrapper #(
      .AXI_ADDR_WIDTH       (fpga_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
      .AXI_DATA_WIDTH       (fpga_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
      .AXI_ID_WIDTH         (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
      .AXI_USER_WIDTH       (fpga_picobello_pkg::AxiCfgWTrafficGen.UserWidth),
      .AXI_LOCK             (1),
      .AXI_LITE_ADDR_WIDTH  (fpga_picobello_pkg::AxiLiteCfg.AddrWidth),
      .AXI_LITE_DATA_WIDTH  (fpga_picobello_pkg::AxiLiteCfg.DataWidth)
    ) i_axi_hls_tg_wrapper (
      .clk_i                    (clk_i),
      .rst_ni                   (rst_ni),
      .axi_tg_wide_out          (cluster_rt_wide_out[i]),
      .axi_lite_read_regfile    (axi_lite_read_regfile[i]),
      .axi_lite_write_regfile   (axi_lite_write_regfile[i]),
      .axi_lite_comp_regfile    (axi_lite_comp_regfile[i])
    );

    `AXI_ASSIGN_TO_REQ(cluster_rt_wide_out_req[i], cluster_rt_wide_out[i])
    `AXI_ASSIGN_FROM_RESP(cluster_rt_wide_out[i], cluster_rt_wide_out_rsp[i])

    // Bind to AXI-Realm inputs
    `AXI_ASSIGN_REQ_STRUCT(axi_realm_in_req[i], cluster_rt_wide_out_req[i])
    `AXI_ASSIGN_RESP_STRUCT(cluster_rt_wide_out_rsp[i], axi_realm_in_rsp[i])
  end

  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (NumCores < NumCoresMax) else $fatal(1, "Wrong number of cores");
    assert (fpga_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth + $clog2(NumCores) == floo_picobello_noc_pkg::AxiCfgW.InIdWidth) else $fatal(1, "Wrong ID width configuration for wide traffic toward FlooNoC!");
  end
  `endif
  // pragma translate_on
endmodule