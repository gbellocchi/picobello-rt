// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module traffic_gen_tile
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
#(
  /// Number of traffic generators per NoC plane.
  parameter int unsigned NumTrafficGen = 1,
  parameter int unsigned NumTrafficGenMax = 32,
  parameter logic [floo_picobello_noc_pkg::AxiCfgW.AddrWidth-1:0] BaseAddr = 32'h0,
  parameter id_t Id = '0
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
    .InFifoDepth (picobello_pkg::RouterInFifoDepth),
    .OutFifoDepth(picobello_pkg::RouterOutFifoDepth),
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
  floo_picobello_noc_pkg::axi_wide_out_req_t chimney_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t chimney_wide_out_rsp;
  floo_picobello_noc_pkg::axi_wide_in_req_t chimney_wide_in_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t chimney_wide_in_rsp;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) chimney_narrow_out[0:0]();

  localparam chimney_cfg_t ChimneyCfgN = set_ports(picobello_pkg::ChimneyClusterRtCfg, 1'b1, 1'b1);
  localparam chimney_cfg_t ChimneyCfgW = set_ports(picobello_pkg::ChimneyClusterRtCfg, 1'b1, 1'b1);

  floo_nw_chimney #(
    .AxiCfgN             (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW             (floo_picobello_noc_pkg::AxiCfgW),
    .ChimneyCfgN         (ChimneyCfgN),
    .ChimneyCfgW         (ChimneyCfgW),
    .RouteCfg            (floo_picobello_noc_pkg::RouteCfg),
    .AtopSupport         (picobello_pkg::ClusterRtAtopSupport), 
    .MaxAtomicTxns       (picobello_pkg::ClusterRtMaxAtomicTxns),
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
    .axi_narrow_in_req_i (chimney_narrow_in_req),
    .axi_narrow_in_rsp_o (chimney_narrow_in_rsp),
    .axi_narrow_out_req_o(chimney_narrow_out_req),
    .axi_narrow_out_rsp_i(chimney_narrow_out_rsp),
    .axi_wide_in_req_i   (chimney_wide_in_req),
    .axi_wide_in_rsp_o   (chimney_wide_in_rsp),
    .axi_wide_out_req_o  (chimney_wide_out_req),
    .axi_wide_out_rsp_i  (chimney_wide_out_rsp),
    .floo_req_o          (router_floo_req_in[Eject]),
    .floo_rsp_o          (router_floo_rsp_in[Eject]),
    .floo_wide_o         (router_floo_wide_in[Eject]),
    .floo_req_i          (router_floo_req_out[Eject]),
    .floo_rsp_i          (router_floo_rsp_out[Eject]),
    .floo_wide_i         (router_floo_wide_out[Eject])
  );

  `AXI_ASSIGN_FROM_REQ(chimney_narrow_out[0], chimney_narrow_out_req)
  `AXI_ASSIGN_TO_RESP(chimney_narrow_out_rsp, chimney_narrow_out[0])

  ///////////////////////////////////////////////////////////////////////////
  // AXI4 narrow chimney => AXI4 narrow traffic generators (configuration) //
  ///////////////////////////////////////////////////////////////////////////

  //                    +------+
  //                    |      |
  //   NI narrow out -->| XBAR |--> axi_traffic_gen[wide]
  //   (AXI4, 64 bit)   |      |--> axi_traffic_gen[narrow]
  //                    +------+

  // Traffic generator address map
  axi_narrow_out_addr_t traffic_gen_addr_space_dim = 32'h0000_2000; // Max number of addressable masters = 32

  // Address map
  axi_pkg::xbar_rule_64_t [NumTrafficGenTotal-1:0] ni2tg_addr_map;

  localparam axi_pkg::xbar_cfg_t XbarCfgNi2Tg = '{
    NoSlvPorts:         1, // Thus no ID expansion for outputs
    NoMstPorts:         NumTrafficGenTotal,
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
    NoAddrRules:        NumTrafficGenTotal
  };

  // AXI4 traffic generator ports
  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) axi_traffic_gen [NumTrafficGenTotal-1:0]();

  // Address map
  for (genvar i = 0; i < NumTrafficGenTotal; i++) begin : gen_rt_tile_ni2tg_addr_map
    assign ni2tg_addr_map[i] = '{
      idx:        i,
      start_addr: base_addr_i + i * traffic_gen_addr_space_dim,
      end_addr:   base_addr_i + (i + 1) * traffic_gen_addr_space_dim
    };
  end

  axi_xbar_intf #(
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
    .Cfg            (XbarCfgNi2Tg),
    .ATOPS          (1'b0),
    .rule_t         (axi_pkg::xbar_rule_64_t)
  ) i_rt_tile_ni2tg_xbar (
    .clk_i,
    .rst_ni,
    .test_i                 (1'b0),
    .slv_ports              (chimney_narrow_out),
    .mst_ports              (axi_traffic_gen),
    .addr_map_i             (ni2tg_addr_map),
    .en_default_mst_port_i  ('0),
    .default_mst_port_i     ('0)
  );

  /////////////////////////////////////////////////////////////////////////////
  // AXI4 narrow traffic generators => AXI4 traffic generator register files //
  /////////////////////////////////////////////////////////////////////////////

  // Each traffic generator can be configured independently accessing the following register files:
  // - Traffic generator read configuration
  // - Traffic generator write configuration
  // - Traffic generator compute configuration
  // - AXI-Realm configuration
  //
  //                         +------+
  //                         |      |--> axi_tg_regfile[i][realm]
  //   axi_traffic_gen[i] -->| XBAR |--> axi_tg_regfile[i][read]
  //                         |      |--> axi_tg_regfile[i][write]
  //                         |      |--> axi_tg_regfile[i][compute]
  //                         +------+

  localparam int unsigned NumTrafficGenRegFiles = 4;

  // Number of address map rules
  localparam int unsigned NumTrafficGenRegFileRules = 3;
  localparam int unsigned NumAxiRealmRules = 1;
  localparam int unsigned NumRulesTg2RegFile = NumTrafficGenRegFileRules + NumAxiRealmRules;

  // Indices
  localparam int unsigned IdxPortAxiRealm          = 0;
  localparam int unsigned IdxPortTrafficGenRead    = 1;
  localparam int unsigned IdxPortTrafficGenWrite   = 2;
  localparam int unsigned IdxPortTrafficGenCompute = 3;

  // Traffic generator register files address map
  axi_narrow_out_addr_t cluster_rt_addr_dim = 32'h0000_1000;
  axi_narrow_out_addr_t cluster_dma_r_addr_dim = 32'h0000_0100;
  axi_narrow_out_addr_t cluster_dma_w_addr_dim = 32'h0000_0100;
  axi_narrow_out_addr_t cluster_compute_addr_dim = 32'h0000_0100; // not used

  axi_narrow_out_addr_t cluster_rt_addr_offset = 32'h0000_0000;
  axi_narrow_out_addr_t cluster_dma_r_addr_offset = cluster_rt_addr_offset + cluster_rt_addr_dim;
  axi_narrow_out_addr_t cluster_dma_w_addr_offset = cluster_dma_r_addr_offset + cluster_dma_r_addr_dim;
  axi_narrow_out_addr_t cluster_compute_addr_offset = cluster_dma_w_addr_offset + cluster_dma_w_addr_dim;

  // AXI4 traffic generator register files
  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) axi_tg_regfile [NumTrafficGenTotal-1:0][NumTrafficGenRegFiles-1:0]();

  // Address map
  axi_pkg::xbar_rule_64_t [NumTrafficGenTotal-1:0][NumRulesTg2RegFile-1:0] tg2regfile_addr_map;

  localparam axi_pkg::xbar_cfg_t XbarCfgTg2RegFile = '{
    NoSlvPorts:         1, // Thus no ID expansion for outputs
    NoMstPorts:         NumTrafficGenRegFiles,
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
    NoAddrRules:        NumRulesTg2RegFile
  };

  for (genvar i = 0; i < NumTrafficGenTotal; i++) begin : gen_rt_tile_tg2regfile_xbar

    // AXI-Realm port configuration
    assign tg2regfile_addr_map[i][0] = '{
      idx:        IdxPortAxiRealm,
      start_addr: base_addr_i + i * traffic_gen_addr_space_dim + cluster_rt_addr_offset,
      end_addr:   base_addr_i + i * traffic_gen_addr_space_dim + cluster_rt_addr_offset + cluster_rt_addr_dim
    };

    // Read configuration
    assign tg2regfile_addr_map[i][1] = '{
      idx:        IdxPortTrafficGenRead,
      start_addr: base_addr_i + i * traffic_gen_addr_space_dim + cluster_dma_r_addr_offset,
      end_addr:   base_addr_i + i * traffic_gen_addr_space_dim + cluster_dma_r_addr_offset + cluster_dma_r_addr_dim
    };

    // Write configuration
    assign tg2regfile_addr_map[i][2] = '{
      idx:        IdxPortTrafficGenWrite,
      start_addr: base_addr_i + i * traffic_gen_addr_space_dim + cluster_dma_w_addr_offset,
      end_addr:   base_addr_i + i * traffic_gen_addr_space_dim + cluster_dma_w_addr_offset + cluster_dma_w_addr_dim
    };

    // Timer (compute)
    assign tg2regfile_addr_map[i][3] = '{
      idx:        IdxPortTrafficGenCompute,
      start_addr: base_addr_i + i * traffic_gen_addr_space_dim + cluster_compute_addr_offset,
      end_addr:   base_addr_i + i * traffic_gen_addr_space_dim + cluster_compute_addr_offset + cluster_compute_addr_dim
    };

    axi_xbar_intf #(
      .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
      .Cfg            (XbarCfgTg2RegFile),
      .ATOPS          (1'b0),
      .rule_t         (axi_pkg::xbar_rule_64_t)
    ) i_rt_tile_tg2regfile_xbar (
      .clk_i,
      .rst_ni,
      .test_i                 (1'b0),
      .slv_ports              (axi_traffic_gen[i:i]),
      .mst_ports              (axi_tg_regfile[i]),
      .addr_map_i             (tg2regfile_addr_map[i]),
      .en_default_mst_port_i  ('0),
      .default_mst_port_i     ('0)
    );
  end

  /////////////////////////////////////////////////////////////////////////////
  // AXI4 traffic generator register files (64 bit) => Register bus (32 bit) //
  /////////////////////////////////////////////////////////////////////////////

  //                           +------------+
  //   axi_tg_regfile[i][j] -->| AXI_TO_REG |--> regbus_tg_regfile[i][j]
  //   (AXI4, 64 bit)          |            |    (reg bus, 32 bit)
  //                           +------------+

  floo_picobello_noc_pkg::axi_narrow_out_req_t [NumTrafficGenTotal-1:0][NumTrafficGenRegFiles-1:0] axi_tg_regfile_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t [NumTrafficGenTotal-1:0][NumTrafficGenRegFiles-1:0] axi_tg_regfile_rsp;

  axi_rt_cfg_req_t [NumTrafficGenTotal-1:0][NumTrafficGenRegFiles-1:0] regbus_tg_regfile_req;
  axi_rt_cfg_rsp_t [NumTrafficGenTotal-1:0][NumTrafficGenRegFiles-1:0] regbus_tg_regfile_rsp;

  for (genvar i = 0; i < NumTrafficGenTotal; i++) begin : gen_tg_regfile_axi_to_reg_i
    for (genvar j = 0; j < NumTrafficGenRegFiles; j++) begin : gen_tg_regfile_axi_to_reg_j

      `AXI_ASSIGN_TO_REQ(axi_tg_regfile_req[i][j], axi_tg_regfile[i][j])
      `AXI_ASSIGN_FROM_RESP(axi_tg_regfile[i][j], axi_tg_regfile_rsp[i][j])

      axi_to_reg_v2 #(
        .AxiAddrWidth (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
        .AxiDataWidth (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
        .AxiIdWidth   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
        .AxiUserWidth (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
        .RegDataWidth (picobello_pkg::AxiRtCfgDataWidth),
        .CutMemReqs   (1'b0),
        .CutMemRsps   (1'b0),
        .axi_req_t    (floo_picobello_noc_pkg::axi_narrow_out_req_t),
        .axi_rsp_t    (floo_picobello_noc_pkg::axi_narrow_out_rsp_t),
        .reg_req_t    (axi_rt_cfg_req_t),
        .reg_rsp_t    (axi_rt_cfg_rsp_t)
      ) i_axi_to_reg_tg_regfile (
        .clk_i,
        .rst_ni,
        .axi_req_i  (axi_tg_regfile_req[i][j]),
        .axi_rsp_o  (axi_tg_regfile_rsp[i][j]),
        .reg_req_o  (regbus_tg_regfile_req[i][j]),
        .reg_rsp_i  (regbus_tg_regfile_rsp[i][j]),
        .reg_id_o   (),
        .busy_o     ()
      );
    end
  end

  //////////////////////////////////////////////////////////////////////
  // Traffic generator register buses => Register buses per NoC plane //
  //////////////////////////////////////////////////////////////////////

  axi_rt_cfg_req_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_read_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_read_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_write_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_write_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_comp_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_comp_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_realm_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0][NumTrafficGen-1:0] regbus_realm_regfile_rsp;

  for (genvar i = 0; i < NumNoCPlanes; i++) begin : gen_tg_regfile_noc_plane_i
    for (genvar j = 0; j < NumTrafficGen; j++) begin : gen_tg_regfile_noc_plane_j

      assign regbus_realm_regfile_req[i][j] = regbus_tg_regfile_req[i * NumTrafficGen + j][IdxPortAxiRealm];
      assign regbus_tg_regfile_rsp[i * NumTrafficGen + j][IdxPortAxiRealm] = regbus_realm_regfile_rsp[i][j];

      assign regbus_read_regfile_req[i][j] = regbus_tg_regfile_req[i * NumTrafficGen + j][IdxPortTrafficGenRead];
      assign regbus_tg_regfile_rsp[i * NumTrafficGen + j][IdxPortTrafficGenRead] = regbus_read_regfile_rsp[i][j];

      assign regbus_write_regfile_req[i][j] = regbus_tg_regfile_req[i * NumTrafficGen + j][IdxPortTrafficGenWrite];
      assign regbus_tg_regfile_rsp[i * NumTrafficGen + j][IdxPortTrafficGenWrite] = regbus_write_regfile_rsp[i][j];

      assign regbus_comp_regfile_req[i][j] = regbus_tg_regfile_req[i * NumTrafficGen + j][IdxPortTrafficGenCompute];
      assign regbus_tg_regfile_rsp[i * NumTrafficGen + j][IdxPortTrafficGenCompute] = regbus_comp_regfile_rsp[i][j];
    end
  end

  //////////////////////////////////
  // AXI4 wide traffic generators //
  //////////////////////////////////

  //   +-----+     +-----------+     +-----+
  //   | DMA |---->| AXI-REALM |---->| MUX |--> NI wide in
  //   +-----+     +-----------+     +-----+

  // Output data traffic
  axi_wide_traffic_gen_req_t [NumTrafficGen-1:0] cluster_rt_wide_out_req;
  axi_wide_traffic_gen_rsp_t [NumTrafficGen-1:0] cluster_rt_wide_out_rsp;

  localparam int unsigned FlooDmaWideIndex = int'(Id.x) * picobello_pkg::MeshDim.y + int'(Id.y);

  floo_dma_test_wrapper #(
    .NumTrafficGen      ( NumTrafficGen                    ),
    .NumPending         ( 32                               ),
    .Id                 ( Id                               ),
    .FlooDmaIndex       ( FlooDmaWideIndex                 ),
    .FlooDmaMemBaseAddr ( BaseAddr                         ),
    .AxiCfg             ( picobello_pkg::AxiCfgWTrafficGen ),
    .AxiLock            ( 1                                ),
    .axi_in_req_t       ( axi_wide_traffic_gen_req_t       ),
    .axi_in_rsp_t       ( axi_wide_traffic_gen_rsp_t       ),
    .axi_out_req_t      ( axi_wide_traffic_gen_req_t       ),
    .axi_out_rsp_t      ( axi_wide_traffic_gen_rsp_t       ),
    .reg_req_t          ( axi_rt_cfg_req_t                 ),
    .reg_rsp_t          ( axi_rt_cfg_rsp_t                 )
  ) i_wide_axi_traffic_gen_wrapper (
    .clk_i                        ( clk_i                                       ),
    .rst_ni                       ( rst_ni                                      ),
    .axi_in_req_i                 ( '0                                          ),
    .axi_in_rsp_o                 (                                             ),
    .axi_out_req_o                ( cluster_rt_wide_out_req                     ),
    .axi_out_rsp_i                ( cluster_rt_wide_out_rsp                     ),
    .regbus_read_regfile_req      ( regbus_read_regfile_req[IdxNoCPlaneWide]    ),
    .regbus_read_regfile_rsp      ( regbus_read_regfile_rsp[IdxNoCPlaneWide]    ),
    .regbus_write_regfile_req     ( regbus_write_regfile_req[IdxNoCPlaneWide]   ),
    .regbus_write_regfile_rsp     ( regbus_write_regfile_rsp[IdxNoCPlaneWide]   ),
    .regbus_compute_regfile_req   ( regbus_comp_regfile_req[IdxNoCPlaneWide]    ),
    .regbus_compute_regfile_rsp   ( regbus_comp_regfile_rsp[IdxNoCPlaneWide]    )
  );

  // Bind wide cluster outputs to AXI-Realm wide inputs
  for (genvar i = 0; i < NumTrafficGen; i++) begin : gen_axi_rt_wide_bindings
    `AXI_ASSIGN_REQ_STRUCT(axi_realm_wide_in_req[i], cluster_rt_wide_out_req[i])
    `AXI_ASSIGN_RESP_STRUCT(cluster_rt_wide_out_rsp[i], axi_realm_wide_in_rsp[i])
  end

  ////////////////////////////
  // AXI-Realm wide traffic //
  ////////////////////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  // AXI-Realm wide input traffic
  axi_wide_traffic_gen_req_t [NumTrafficGen-1:0] axi_realm_wide_in_req;
  axi_wide_traffic_gen_rsp_t [NumTrafficGen-1:0] axi_realm_wide_in_rsp;

  // AXI-Realm wide output traffic 
  axi_wide_traffic_gen_req_t [NumTrafficGen-1:0] axi_realm_wide_out_req;
  axi_wide_traffic_gen_rsp_t [NumTrafficGen-1:0] axi_realm_wide_out_rsp;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH (picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .AXI_ID_WIDTH   (picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .AXI_USER_WIDTH (picobello_pkg::AxiCfgWTrafficGen.UserWidth)
  ) axi_realm_wide_out [NumTrafficGen-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgW.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgW.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgW.InIdWidth), // Changed from OutIdWidth to InIdWidth
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgW.UserWidth)
  ) axi_realm_wide_out_mux ();

  // Register bus signals
  axi_rt_cfg_req_t regbus_realm_wide_regfile_req; 
  axi_rt_cfg_rsp_t regbus_realm_wide_regfile_rsp;

  // AXI RT IDs
  slv_id_t realm_wide_regfile_id;

  // The AXI-Realm register file of a NoC plane is shared by the DMAs of that plane.
  // With more than one DMA, their register buses need an arbiter here.
  if (NumTrafficGen == 1) begin : gen_regfile_realm_wide
    assign regbus_realm_wide_regfile_req = regbus_realm_regfile_req[IdxNoCPlaneWide][0];
    assign regbus_realm_regfile_rsp[IdxNoCPlaneWide][0] = regbus_realm_wide_regfile_rsp;
  end else begin : gen_regfile_realm_wide_unsupported
    $fatal(1, "AXI-Realm register file access is only supported with one DMA per NoC plane.");
  end

  // Calculate Realm register file ID
  assign realm_wide_regfile_id = id_i.y + MeshDim.y * id_i.x;

  // AXI RT unit wide
  axi_rt_unit_top #(
    .NumManagers       (NumTrafficGen),
    .AddrWidth         (picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .DataWidth         (picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .IdWidth           (picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .UserWidth         (picobello_pkg::AxiCfgWTrafficGen.UserWidth),
    .NumPending        (NumPending),
    .WBufferDepth      (WBufferDepth),
    .NumAddrRegions    (NumRegions),
    .BudgetWidth       (BudgetWidth),
    .PeriodWidth       (PeriodWidth),
    .RegIdWidth        (AxiSlvIdWidth),
    .AxiSizeWidth      (axi_pkg::SizeWidth+1),
    .CutDecErrors      (1'b0),
    .CutSplitterPaths  (1'b0),
    .UseWriteBuffer    (1'b0),
    .UseSplitterReconf (1'b1),
    .aw_chan_t         (axi_wide_traffic_gen_aw_chan_t),
    .ar_chan_t         (axi_wide_traffic_gen_ar_chan_t),
    .w_chan_t          (axi_wide_traffic_gen_w_chan_t),
    .r_chan_t          (axi_wide_traffic_gen_r_chan_t),
    .b_chan_t          (axi_wide_traffic_gen_b_chan_t),
    .axi_req_t         (axi_wide_traffic_gen_req_t),
    .axi_resp_t        (axi_wide_traffic_gen_rsp_t),
    .req_req_t         (axi_rt_cfg_req_t),
    .req_rsp_t         (axi_rt_cfg_rsp_t)
  ) i_axi_rt_unit_wide (
    .clk_i,
    .rst_ni,
    .slv_req_i         (axi_realm_wide_in_req),
    .slv_resp_o        (axi_realm_wide_in_rsp),
    .mst_req_o         (axi_realm_wide_out_req),
    .mst_resp_i        (axi_realm_wide_out_rsp), 
    .reg_req_i         (regbus_realm_wide_regfile_req), 
    .reg_rsp_o         (regbus_realm_wide_regfile_rsp), 
    .reg_id_i          (realm_wide_regfile_id)  
  );

  // Bind AXI-Realm wide outputs
  for (genvar i = 0; i < NumTrafficGen; i++) begin : gen_rt_tile_axirt2ni_wide_assign
    `AXI_ASSIGN_FROM_REQ(axi_realm_wide_out[i], axi_realm_wide_out_req[i])
    `AXI_ASSIGN_TO_RESP(axi_realm_wide_out_rsp[i], axi_realm_wide_out[i])
  end

  // Mux AXI4 wide outputs to the FlooNoC NI
  axi_mux_intf #(
    .SLV_AXI_ID_WIDTH   (picobello_pkg::AxiCfgWTrafficGen.OutIdWidth), // traffic generator ID width
    .MST_AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgW.InIdWidth), // expanded, based on NumTrafficGen, and matching NI ID width
    .AXI_ADDR_WIDTH     (picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH     (picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .AXI_USER_WIDTH     (picobello_pkg::AxiCfgWTrafficGen.UserWidth),
    .NO_SLV_PORTS       (NumTrafficGen),
    .MAX_W_TRANS        (NumTrafficGenMax),
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
    .slv      (axi_realm_wide_out),
    .mst      (axi_realm_wide_out_mux)
  );

  `AXI_ASSIGN_TO_REQ(chimney_wide_in_req, axi_realm_wide_out_mux)
  `AXI_ASSIGN_FROM_RESP(axi_realm_wide_out_mux, chimney_wide_in_rsp)

  //////////////////////////////////
  // AXI4 narrow traffic generators //
  //////////////////////////////////

  //   +-----+     +-----------+     +-----+
  //   | DMA |---->| AXI-REALM |---->| MUX |--> NI narrow in
  //   +-----+     +-----------+     +-----+

  // Output data traffic
  axi_narrow_traffic_gen_req_t [NumTrafficGen-1:0] cluster_rt_narrow_out_req;
  axi_narrow_traffic_gen_rsp_t [NumTrafficGen-1:0] cluster_rt_narrow_out_rsp;

  localparam int unsigned FlooDmaNarrowIndex = 100 + int'(Id.x) * picobello_pkg::MeshDim.y + int'(Id.y);

  floo_dma_test_wrapper #(
    .NumTrafficGen      ( NumTrafficGen                    ),
    .NumPending         ( 32                               ),
    .Id                 ( Id                               ),
    .FlooDmaIndex       ( FlooDmaNarrowIndex               ),
    .FlooDmaMemBaseAddr ( BaseAddr                         ),
    .AxiCfg             ( picobello_pkg::AxiCfgNTrafficGen ),
    .AxiLock            ( 1                                ),
    .axi_in_req_t       ( axi_narrow_traffic_gen_req_t     ),
    .axi_in_rsp_t       ( axi_narrow_traffic_gen_rsp_t     ),
    .axi_out_req_t      ( axi_narrow_traffic_gen_req_t     ),
    .axi_out_rsp_t      ( axi_narrow_traffic_gen_rsp_t     ),
    .reg_req_t          ( axi_rt_cfg_req_t                 ),
    .reg_rsp_t          ( axi_rt_cfg_rsp_t                 )
  ) i_narrow_axi_traffic_gen_wrapper (
    .clk_i                        ( clk_i                                         ),
    .rst_ni                       ( rst_ni                                        ),
    .axi_in_req_i                 ( '0                                            ),
    .axi_in_rsp_o                 (                                               ),
    .axi_out_req_o                ( cluster_rt_narrow_out_req                     ),
    .axi_out_rsp_i                ( cluster_rt_narrow_out_rsp                     ),
    .regbus_read_regfile_req      ( regbus_read_regfile_req[IdxNoCPlaneNarrow]  ),
    .regbus_read_regfile_rsp      ( regbus_read_regfile_rsp[IdxNoCPlaneNarrow]  ),
    .regbus_write_regfile_req     ( regbus_write_regfile_req[IdxNoCPlaneNarrow] ),
    .regbus_write_regfile_rsp     ( regbus_write_regfile_rsp[IdxNoCPlaneNarrow] ),
    .regbus_compute_regfile_req   ( regbus_comp_regfile_req[IdxNoCPlaneNarrow]  ),
    .regbus_compute_regfile_rsp   ( regbus_comp_regfile_rsp[IdxNoCPlaneNarrow]  )
  );

  // Bind narrow cluster outputs to AXI-Realm narrow inputs
  for (genvar i = 0; i < NumTrafficGen; i++) begin : gen_axi_rt_narrow_bindings
    `AXI_ASSIGN_REQ_STRUCT(axi_realm_narrow_in_req[i], cluster_rt_narrow_out_req[i])
    `AXI_ASSIGN_RESP_STRUCT(cluster_rt_narrow_out_rsp[i], axi_realm_narrow_in_rsp[i])
  end

  //////////////////////////////
  // AXI-Realm narrow traffic //
  //////////////////////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  // AXI-Realm narrow input traffic
  axi_narrow_traffic_gen_req_t [NumTrafficGen-1:0] axi_realm_narrow_in_req;
  axi_narrow_traffic_gen_rsp_t [NumTrafficGen-1:0] axi_realm_narrow_in_rsp;

  // AXI-Realm narrow output traffic 
  axi_narrow_traffic_gen_req_t [NumTrafficGen-1:0] axi_realm_narrow_out_req;
  axi_narrow_traffic_gen_rsp_t [NumTrafficGen-1:0] axi_realm_narrow_out_rsp;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (picobello_pkg::AxiCfgNTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH (picobello_pkg::AxiCfgNTrafficGen.DataWidth),
    .AXI_ID_WIDTH   (picobello_pkg::AxiCfgNTrafficGen.OutIdWidth),
    .AXI_USER_WIDTH (picobello_pkg::AxiCfgNTrafficGen.UserWidth)
  ) axi_realm_narrow_out [NumTrafficGen-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (picobello_pkg::AxiCfgNTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH (picobello_pkg::AxiCfgNTrafficGen.DataWidth),
    .AXI_ID_WIDTH   (picobello_pkg::AxiCfgNTrafficGen.InIdWidth),
    .AXI_USER_WIDTH (picobello_pkg::AxiCfgNTrafficGen.UserWidth)
  ) axi_realm_narrow_out_mux ();

  // Register bus signals
  axi_rt_cfg_req_t regbus_realm_narrow_regfile_req; 
  axi_rt_cfg_rsp_t regbus_realm_narrow_regfile_rsp;

  // AXI RT IDs
  slv_id_t realm_narrow_regfile_id;

  // The AXI-Realm register file of a NoC plane is shared by the DMAs of that plane.
  // With more than one DMA, their register buses need an arbiter here.
  if (NumTrafficGen == 1) begin : gen_regfile_realm_narrow
    assign regbus_realm_narrow_regfile_req = regbus_realm_regfile_req[IdxNoCPlaneNarrow][0];
    assign regbus_realm_regfile_rsp[IdxNoCPlaneNarrow][0] = regbus_realm_narrow_regfile_rsp;
  end else begin : gen_regfile_realm_narrow_unsupported
    $fatal(1, "AXI-Realm register file access is only supported with one DMA per NoC plane.");
  end

  // Calculate Realm register file ID
  assign realm_narrow_regfile_id = id_i.y + MeshDim.y * id_i.x;

  // AXI RT unit narrow
  axi_rt_unit_top #(
    .NumManagers       (NumTrafficGen),
    .AddrWidth         (picobello_pkg::AxiCfgNTrafficGen.AddrWidth),
    .DataWidth         (picobello_pkg::AxiCfgNTrafficGen.DataWidth),
    .IdWidth           (picobello_pkg::AxiCfgNTrafficGen.OutIdWidth),
    .UserWidth         (picobello_pkg::AxiCfgNTrafficGen.UserWidth),
    .NumPending        (NumPending),
    .WBufferDepth      (WBufferDepth),
    .NumAddrRegions    (NumRegions),
    .BudgetWidth       (BudgetWidth),
    .PeriodWidth       (PeriodWidth),
    .RegIdWidth        (AxiSlvIdWidth),
    .AxiSizeWidth      (axi_pkg::SizeWidth),
    .CutDecErrors      (1'b0),
    .CutSplitterPaths  (1'b0),
    .UseWriteBuffer    (1'b0),
    .UseSplitterReconf (1'b1),
    .aw_chan_t         (axi_narrow_traffic_gen_aw_chan_t),
    .ar_chan_t         (axi_narrow_traffic_gen_ar_chan_t),
    .w_chan_t          (axi_narrow_traffic_gen_w_chan_t),
    .r_chan_t          (axi_narrow_traffic_gen_r_chan_t),
    .b_chan_t          (axi_narrow_traffic_gen_b_chan_t),
    .axi_req_t         (axi_narrow_traffic_gen_req_t),
    .axi_resp_t        (axi_narrow_traffic_gen_rsp_t),
    .req_req_t         (axi_rt_cfg_req_t),
    .req_rsp_t         (axi_rt_cfg_rsp_t)
  ) i_axi_rt_unit_narrow (
    .clk_i,
    .rst_ni,
    .slv_req_i         (axi_realm_narrow_in_req),
    .slv_resp_o        (axi_realm_narrow_in_rsp),
    .mst_req_o         (axi_realm_narrow_out_req),
    .mst_resp_i        (axi_realm_narrow_out_rsp), 
    .reg_req_i         (regbus_realm_narrow_regfile_req), 
    .reg_rsp_o         (regbus_realm_narrow_regfile_rsp), 
    .reg_id_i          (realm_narrow_regfile_id)  
  );

  // Bind AXI-Realm narrow outputs
  for (genvar i = 0; i < NumTrafficGen; i++) begin : gen_rt_tile_axirt2ni_narrow_assign
    `AXI_ASSIGN_FROM_REQ(axi_realm_narrow_out[i], axi_realm_narrow_out_req[i])
    `AXI_ASSIGN_TO_RESP(axi_realm_narrow_out_rsp[i], axi_realm_narrow_out[i])
  end

  // Mux AXI4 narrow outputs to the FlooNoC NI
  axi_mux_intf #(
    .SLV_AXI_ID_WIDTH   (picobello_pkg::AxiCfgNTrafficGen.OutIdWidth), // traffic generator ID width
    .MST_AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.InIdWidth), // expanded, based on NumTrafficGen, and matching NI ID width
    .AXI_ADDR_WIDTH     (picobello_pkg::AxiCfgNTrafficGen.AddrWidth),
    .AXI_DATA_WIDTH     (picobello_pkg::AxiCfgNTrafficGen.DataWidth),
    .AXI_USER_WIDTH     (picobello_pkg::AxiCfgNTrafficGen.UserWidth),
    .NO_SLV_PORTS       (NumTrafficGen),
    .MAX_W_TRANS        (NumTrafficGenMax),
    .FALL_THROUGH       (1'b0),
    .SPILL_AW           (1'b1),
    .SPILL_W            (1'b1),
    .SPILL_B            (1'b1),
    .SPILL_AR           (1'b1),
    .SPILL_R            (1'b1)
  ) i_axi_narrow_out_rt2ni_mux (
    .clk_i,                
    .rst_ni,
    .test_i   (1'b0),
    .slv      (axi_realm_narrow_out),
    .mst      (axi_realm_narrow_out_mux)
  );

  `AXI_ASSIGN_TO_REQ(chimney_narrow_in_req, axi_realm_narrow_out_mux)
  `AXI_ASSIGN_FROM_RESP(axi_realm_narrow_out_mux, chimney_narrow_in_rsp)

  ///////////////////////
  // Local tile memory //
  ///////////////////////

  // Emulate L1 SPM inside cluster tile.
  floo_axi_rand_slave #(
    .AxiCfg       ( floo_picobello_noc_pkg::AxiCfgW            ),
    .ApplTime     ( sim_picobello_pkg::ApplTime                ),
    .TestTime     ( sim_picobello_pkg::TestTime                ),
    .SlaveType    ( floo_test_pkg::IdealSlave                  ),
    .NumSlaves    ( 1                                          ),
    .axi_req_t    ( floo_picobello_noc_pkg::axi_wide_out_req_t ),
    .axi_rsp_t    ( floo_picobello_noc_pkg::axi_wide_out_rsp_t )
  ) i_sink_in_mem (
    .clk_i              ( clk_i                ),
    .rst_ni             ( rst_ni               ),
    .slv_port_req_i     ( chimney_wide_out_req ),
    .slv_port_rsp_o     ( chimney_wide_out_rsp ),
    .mon_mst_port_req_o (                      ),
    .mon_mst_port_rsp_o (                      )
  );
  
  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (NumTrafficGen < NumTrafficGenMax) else $fatal(1, "Wrong number of traffic generators");
    assert (picobello_pkg::AxiCfgWTrafficGen.OutIdWidth + $clog2(NumTrafficGen) == floo_picobello_noc_pkg::AxiCfgW.InIdWidth) else $fatal(1, "Wrong ID width configuration for wide traffic toward FlooNoC!");
  end
  `endif
  // pragma translate_on
endmodule