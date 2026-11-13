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
  import sim_picobello_pkg::*;
#(
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

  localparam chimney_cfg_t ChimneyCfgN = set_ports(picobello_pkg::ChimneyClusterCfg, 1'b1, 1'b1);
  localparam chimney_cfg_t ChimneyCfgW = set_ports(picobello_pkg::ChimneyClusterCfg, 1'b1, 1'b1);

  floo_nw_chimney #(
    .AxiCfgN             (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW             (floo_picobello_noc_pkg::AxiCfgW),
    .ChimneyCfgN         (ChimneyCfgN),
    .ChimneyCfgW         (ChimneyCfgW),
    .RouteCfg            (floo_picobello_noc_pkg::RouteCfg),
    .AtopSupport         (picobello_pkg::ClusterAtopSupport),
    .MaxAtomicTxns       (picobello_pkg::ClusterMaxAtomicTxns),
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
  axi_pkg::xbar_rule_64_t [NumNoCPlanes-1:0] ni2tg_addr_map;

  localparam axi_pkg::xbar_cfg_t XbarCfgNi2Tg = '{
    NoSlvPorts:         1, // Thus no ID expansion for outputs
    NoMstPorts:         NumNoCPlanes,
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
    NoAddrRules:        NumNoCPlanes
  };

  // AXI4 traffic generator ports
  AXI_BUS #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth)
  ) axi_traffic_gen [NumNoCPlanes-1:0]();

  // Address map
  for (genvar i = 0; i < NumNoCPlanes; i++) begin : gen_rt_tile_ni2tg_addr_map
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
  ) axi_tg_regfile [NumNoCPlanes-1:0][NumTrafficGenRegFiles-1:0]();

  // Address map
  axi_pkg::xbar_rule_64_t [NumNoCPlanes-1:0][NumRulesTg2RegFile-1:0] tg2regfile_addr_map;

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

  for (genvar i = 0; i < NumNoCPlanes; i++) begin : gen_rt_tile_tg2regfile_xbar

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

  floo_picobello_noc_pkg::axi_narrow_out_req_t [NumNoCPlanes-1:0][NumTrafficGenRegFiles-1:0] axi_tg_regfile_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t [NumNoCPlanes-1:0][NumTrafficGenRegFiles-1:0] axi_tg_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0][NumTrafficGenRegFiles-1:0] regbus_tg_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0][NumTrafficGenRegFiles-1:0] regbus_tg_regfile_rsp;

  for (genvar i = 0; i < NumNoCPlanes; i++) begin : gen_tg_regfile_axi_to_reg_i
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

  axi_rt_cfg_req_t [NumNoCPlanes-1:0] regbus_read_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0] regbus_read_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0] regbus_write_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0] regbus_write_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0] regbus_comp_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0] regbus_comp_regfile_rsp;

  axi_rt_cfg_req_t [NumNoCPlanes-1:0] regbus_realm_regfile_req;
  axi_rt_cfg_rsp_t [NumNoCPlanes-1:0] regbus_realm_regfile_rsp;

  for (genvar i = 0; i < NumNoCPlanes; i++) begin : gen_tg_regfile_noc_plane

    assign regbus_realm_regfile_req[i] = regbus_tg_regfile_req[i][IdxPortAxiRealm];
    assign regbus_tg_regfile_rsp[i][IdxPortAxiRealm] = regbus_realm_regfile_rsp[i];

    assign regbus_read_regfile_req[i] = regbus_tg_regfile_req[i][IdxPortTrafficGenRead];
    assign regbus_tg_regfile_rsp[i][IdxPortTrafficGenRead] = regbus_read_regfile_rsp[i];

    assign regbus_write_regfile_req[i] = regbus_tg_regfile_req[i][IdxPortTrafficGenWrite];
    assign regbus_tg_regfile_rsp[i][IdxPortTrafficGenWrite] = regbus_write_regfile_rsp[i];

    assign regbus_comp_regfile_req[i] = regbus_tg_regfile_req[i][IdxPortTrafficGenCompute];
    assign regbus_tg_regfile_rsp[i][IdxPortTrafficGenCompute] = regbus_comp_regfile_rsp[i];
  end

  //////////////////////////////////
  // AXI4 wide traffic generators //
  //////////////////////////////////

  //   +-----+     +-----------+
  //   | DMA |---->| AXI-REALM |--> NI wide in
  //   +-----+     +-----------+

  // Output data traffic
  axi_wide_traffic_gen_req_t cluster_rt_wide_out_req;
  axi_wide_traffic_gen_rsp_t cluster_rt_wide_out_rsp;

  localparam int unsigned FlooDmaWideIndex = int'(Id.x) * picobello_pkg::MeshDim.y + int'(Id.y);

  floo_dma_test_wrapper #(
    .NumPending         ( 32                               ),
    .Id                 ( Id                               ),
    .FlooDmaIndex       ( FlooDmaWideIndex                 ),
    .FlooDmaMemBaseAddr ( BaseAddr                         ),
    .AxiCfg             ( sim_picobello_pkg::AxiCfgWTrafficGen ),
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
  `AXI_ASSIGN_REQ_STRUCT(axi_realm_wide_in_req, cluster_rt_wide_out_req)
  `AXI_ASSIGN_RESP_STRUCT(cluster_rt_wide_out_rsp, axi_realm_wide_in_rsp)

  ////////////////////////////
  // AXI-Realm wide traffic //
  ////////////////////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  // AXI-Realm wide input traffic
  axi_wide_traffic_gen_req_t axi_realm_wide_in_req;
  axi_wide_traffic_gen_rsp_t axi_realm_wide_in_rsp;

  // AXI-Realm wide output traffic 
  axi_wide_traffic_gen_req_t axi_realm_wide_out_req;
  axi_wide_traffic_gen_rsp_t axi_realm_wide_out_rsp;

  // Register bus signals
  axi_rt_cfg_req_t regbus_realm_wide_regfile_req; 
  axi_rt_cfg_rsp_t regbus_realm_wide_regfile_rsp;

  // AXI RT IDs
  slv_id_t realm_wide_regfile_id;

  // AXI-Realm register file of the wide NoC plane
  assign regbus_realm_wide_regfile_req = regbus_realm_regfile_req[IdxNoCPlaneWide];
  assign regbus_realm_regfile_rsp[IdxNoCPlaneWide] = regbus_realm_wide_regfile_rsp;

  // Calculate Realm register file ID
  assign realm_wide_regfile_id = id_i.y + MeshDim.y * id_i.x;

  // AXI RT unit wide
  axi_rt_unit_top #(
    .NumManagers       (NumManagers),
    .AddrWidth         (sim_picobello_pkg::AxiCfgWTrafficGen.AddrWidth),
    .DataWidth         (sim_picobello_pkg::AxiCfgWTrafficGen.DataWidth),
    .IdWidth           (sim_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth),
    .UserWidth         (sim_picobello_pkg::AxiCfgWTrafficGen.UserWidth),
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

  // Connect AXI-Realm wide outputs directly to the FlooNoC NI (same ID width, no cut)
  `AXI_ASSIGN_REQ_STRUCT(chimney_wide_in_req, axi_realm_wide_out_req)
  `AXI_ASSIGN_RESP_STRUCT(axi_realm_wide_out_rsp, chimney_wide_in_rsp)

  //////////////////////////////////
  // AXI4 narrow traffic generators //
  //////////////////////////////////

  //   +-----+     +-----------+
  //   | DMA |---->| AXI-REALM |--> NI narrow in
  //   +-----+     +-----------+

  // Output data traffic
  axi_narrow_traffic_gen_req_t cluster_rt_narrow_out_req;
  axi_narrow_traffic_gen_rsp_t cluster_rt_narrow_out_rsp;

  localparam int unsigned FlooDmaNarrowIndex = 100 + int'(Id.x) * picobello_pkg::MeshDim.y + int'(Id.y);

  floo_dma_test_wrapper #(
    .NumPending         ( 32                               ),
    .Id                 ( Id                               ),
    .FlooDmaIndex       ( FlooDmaNarrowIndex               ),
    .FlooDmaMemBaseAddr ( BaseAddr                         ),
    .AxiCfg             ( sim_picobello_pkg::AxiCfgNTrafficGen ),
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
  `AXI_ASSIGN_REQ_STRUCT(axi_realm_narrow_in_req, cluster_rt_narrow_out_req)
  `AXI_ASSIGN_RESP_STRUCT(cluster_rt_narrow_out_rsp, axi_realm_narrow_in_rsp)

  //////////////////////////////
  // AXI-Realm narrow traffic //
  //////////////////////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  // AXI-Realm narrow input traffic
  axi_narrow_traffic_gen_req_t axi_realm_narrow_in_req;
  axi_narrow_traffic_gen_rsp_t axi_realm_narrow_in_rsp;

  // AXI-Realm narrow output traffic 
  axi_narrow_traffic_gen_req_t axi_realm_narrow_out_req;
  axi_narrow_traffic_gen_rsp_t axi_realm_narrow_out_rsp;

  // Register bus signals
  axi_rt_cfg_req_t regbus_realm_narrow_regfile_req; 
  axi_rt_cfg_rsp_t regbus_realm_narrow_regfile_rsp;

  // AXI RT IDs
  slv_id_t realm_narrow_regfile_id;

  // AXI-Realm register file of the narrow NoC plane
  assign regbus_realm_narrow_regfile_req = regbus_realm_regfile_req[IdxNoCPlaneNarrow];
  assign regbus_realm_regfile_rsp[IdxNoCPlaneNarrow] = regbus_realm_narrow_regfile_rsp;

  // Calculate Realm register file ID
  assign realm_narrow_regfile_id = id_i.y + MeshDim.y * id_i.x;

  // AXI RT unit narrow
  axi_rt_unit_top #(
    .NumManagers       (NumManagers),
    .AddrWidth         (sim_picobello_pkg::AxiCfgNTrafficGen.AddrWidth),
    .DataWidth         (sim_picobello_pkg::AxiCfgNTrafficGen.DataWidth),
    .IdWidth           (sim_picobello_pkg::AxiCfgNTrafficGen.OutIdWidth),
    .UserWidth         (sim_picobello_pkg::AxiCfgNTrafficGen.UserWidth),
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

  // Connect AXI-Realm narrow outputs directly to the FlooNoC NI (same ID width, no cut)
  `AXI_ASSIGN_REQ_STRUCT(chimney_narrow_in_req, axi_realm_narrow_out_req)
  `AXI_ASSIGN_RESP_STRUCT(axi_realm_narrow_out_rsp, chimney_narrow_in_rsp)

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
    assert (sim_picobello_pkg::AxiCfgWTrafficGen.OutIdWidth == floo_picobello_noc_pkg::AxiCfgW.InIdWidth) else $fatal(1, "Wrong ID width configuration for wide traffic toward FlooNoC!");
    assert (sim_picobello_pkg::AxiCfgNTrafficGen.OutIdWidth == floo_picobello_noc_pkg::AxiCfgN.InIdWidth) else $fatal(1, "Wrong ID width configuration for narrow traffic toward FlooNoC!");
  end
  `endif
  // pragma translate_on
endmodule