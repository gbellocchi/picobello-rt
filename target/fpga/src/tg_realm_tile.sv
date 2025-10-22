// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module tg_realm_tile
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
  input  axi_wide_in_addr_t                       tg_base_addr_i,
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
    .AXI_ADDR_WIDTH (AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgN.UserWidth)
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

  ////////////////////////////////
  // AXI4 Chimney => AXI4 Cores //
  ////////////////////////////////

  // Each NI output is routed toward a specific core for configuration

  ///////////////////////////////////////////
  // AXI4 Cores => AXI4 Core Register Files //
  ///////////////////////////////////////////

  // Each core can be configured independently accessing the following registers:
  // - Traffic generator read configuration (from the Host processor)
  // - Traffic generator write configuration (from the Host processor)
  // - Traffic generator compute configuration (from the Host processor)
  // - AXI-Realm wide port configuration (from the Host processor)

  localparam int unsigned NCoreCfg = 4;

  // Number of address map rules
  localparam int unsigned NTrafficGenRules  = 3;
  localparam int unsigned NAxiRealmRules    = 1;
  localparam int unsigned NTileCfgRules     = NTrafficGenRules + NAxiRealmRules;

  // Indices
  localparam int unsigned IdxPortAxiRealm   = 0;
  localparam int unsigned IdxPortTgRead     = 1;
  localparam int unsigned IdxPortTgWrite    = 2;
  localparam int unsigned IdxPortTgCompute  = 3;

  // AXI4-Lite interfaces - traffic generator configuration
  axi_lite_host_req_t  axi_lite_read_cfg_req;
  axi_lite_host_rsp_t  axi_lite_read_cfg_rsp;

  axi_lite_host_req_t  axi_lite_write_cfg_req;
  axi_lite_host_rsp_t  axi_lite_write_cfg_rsp;

  axi_lite_host_req_t  axi_lite_comp_cfg_req;
  axi_lite_host_rsp_t  axi_lite_comp_cfg_rsp;

  axi_lite_host_req_t  axi_lite_realm_wide_cfg_req;
  axi_lite_host_rsp_t  axi_lite_realm_wide_cfg_rsp;

  // Address map
  axi_pkg::xbar_rule_64_t [NTileCfgRules-1:0] tg_cfg_in_addr_map;

  // Cluster peripheral address map
  axi_narrow_out_addr_downsized_addr_t mst_cfg_partition_dim = 32'h0000_1000; // Max number of addressable masters = 64
  axi_narrow_out_addr_downsized_addr_t multi_mst_cfg_partition_dim = mst_cfg_partition_dim * NumCores;

  axi_narrow_out_addr_downsized_addr_t cluster_tile_rt_addr_offset = 32'h0000_0000;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_dma_r_addr_offset = 32'h0000_0800;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_dma_w_addr_offset = 32'h0000_0830;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_compute_addr_offset = 32'h0000_0860; // not used
  
  axi_narrow_out_addr_downsized_addr_t cluster_tile_rt_addr_dim = 32'h0000_0800;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_dma_r_addr_dim = 32'h0000_0030;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_dma_w_addr_dim = 32'h0000_0030;
  axi_narrow_out_addr_downsized_addr_t cluster_tile_compute_addr_dim = 32'h0000_0030; // not used

  localparam axi_pkg::xbar_cfg_t PicobelloTgXbarCfg = '{
    NoSlvPorts:         1,
    NoMstPorts:         NCoreCfg,
    MaxMstTrans:        4,
    MaxSlvTrans:        4,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     0,
    AxiIdWidthSlvPorts: AxiCfgN.OutIdWidth,
    AxiIdUsedSlvPorts:  1,
    UniqueIds:          0,
    AxiAddrWidth:       AxiCfgN.AddrWidth,
    AxiDataWidth:       AxiCfgN.DataWidth,
    NoAddrRules:        NTileCfgRules
  };

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgN.UserWidth)
  ) axi_tg_tile_cfg [NCoreCfg-1:0]();

  // AXI-Realm wide configuration
  assign tg_cfg_in_addr_map[0] = '{
    idx:        IdxPortAxiRealm,
    start_addr: tg_base_addr_i + cluster_tile_rt_addr_offset,
    end_addr:   tg_base_addr_i + cluster_tile_rt_addr_offset + cluster_tile_rt_addr_dim
  };

  // Wide read
  assign tg_cfg_in_addr_map[1] = '{
    idx:        IdxPortTgRead,
    start_addr: tg_base_addr_i + cluster_tile_dma_r_addr_offset,
    end_addr:   tg_base_addr_i + cluster_tile_dma_r_addr_offset + cluster_tile_dma_r_addr_dim
  };

  // Wide write
  assign tg_cfg_in_addr_map[2] = '{
    idx:        IdxPortTgWrite,
    start_addr: tg_base_addr_i + cluster_tile_dma_w_addr_offset,
    end_addr:   tg_base_addr_i + cluster_tile_dma_w_addr_offset + cluster_tile_dma_w_addr_dim
  };

  // Timer (compute)
  assign tg_cfg_in_addr_map[3] = '{
    idx:        IdxPortTgCompute,
    start_addr: tg_base_addr_i + cluster_tile_compute_addr_offset,
    end_addr:   tg_base_addr_i + cluster_tile_compute_addr_offset + cluster_tile_compute_addr_dim
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH (AxiCfgN.UserWidth),
    .Cfg            (PicobelloTgXbarCfg),
    .ATOPS          (1'b0),
    .rule_t         (axi_pkg::xbar_rule_64_t)
  ) i_tg_tile_cfg_xbar (
    .clk_i,
    .rst_ni,
    .test_i                 (1'b0),
    .slv_ports              (chimney_narrow_out),
    .mst_ports              (axi_tg_tile_cfg),
    .addr_map_i             (tg_cfg_in_addr_map),
    .en_default_mst_port_i  ('0),
    .default_mst_port_i     ('0)
  );

  ///////////////////////////////////////////////////////////////
  // AXI4 Core Register Files => AXI4-Lite Core Register Files //
  ///////////////////////////////////////////////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgDataDownsized.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgDataDownsized.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgDataDownsized.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgDataDownsized.UserWidth)
  ) axi_tg_tile_cfg_data_downsized [NCoreCfg-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgAddrDownsized.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgAddrDownsized.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgAddrDownsized.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgAddrDownsized.UserWidth)
  ) axi_tg_tile_cfg_addr_downsized [NCoreCfg-1:0]();

  axi_narrow_out_addr_downsized_addr_t axi_tg_tile_cfg_addr_downsized_aw_addr[NCoreCfg-1:0];
  axi_narrow_out_addr_downsized_addr_t axi_tg_tile_cfg_addr_downsized_ar_addr[NCoreCfg-1:0];

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_tile_tg_cfg [NCoreCfg-1:0]();

  for (genvar i = 0; i < NCoreCfg; i++) begin : gen_tg_tile_cfg_axi_lite

    axi_dw_converter_intf #(
      .AXI_ID_WIDTH             (AxiCfgDataDownsized.OutIdWidth),
      .AXI_ADDR_WIDTH           (AxiCfgDataDownsized.AddrWidth),
      .AXI_SLV_PORT_DATA_WIDTH  (AxiCfgDataDownsized.DataWidth),
      .AXI_MST_PORT_DATA_WIDTH  (AxiCfgDataDownsized.DataWidth),
      .AXI_USER_WIDTH           (AxiCfgDataDownsized.UserWidth),
      .AXI_MAX_READS            (8)
    ) i_axi_data_converter_tg_tile_cfg (
      .clk_i,
      .rst_ni,
      .slv    (axi_tg_tile_cfg[i]),
      .mst    (axi_tg_tile_cfg_data_downsized[i])
    );

    assign axi_tg_tile_cfg_addr_downsized_aw_addr[i] = axi_tg_tile_cfg_data_downsized[i].aw_addr[31:0];
    assign axi_tg_tile_cfg_addr_downsized_ar_addr[i] = axi_tg_tile_cfg_data_downsized[i].ar_addr[31:0];

    axi_modify_address_intf #(
      .AXI_SLV_PORT_ADDR_WIDTH  (AxiCfgDataDownsized.AddrWidth),
      .AXI_MST_PORT_ADDR_WIDTH  (AxiCfgAddrDownsized.AddrWidth),
      .AXI_DATA_WIDTH           (AxiCfgAddrDownsized.DataWidth),
      .AXI_ID_WIDTH             (AxiCfgAddrDownsized.OutIdWidth),
      .AXI_USER_WIDTH           (AxiCfgAddrDownsized.UserWidth)
    ) i_axi_addr_converter_tg_tile_cfg (
      .slv            (axi_tg_tile_cfg_data_downsized[i]),
      .mst_aw_addr_i  (axi_tg_tile_cfg_addr_downsized_aw_addr[i]),
      .mst_ar_addr_i  (axi_tg_tile_cfg_addr_downsized_ar_addr[i]),
      .mst            (axi_tg_tile_cfg_addr_downsized[i])
    );

    axi_to_axi_lite_intf #(
      .AXI_ADDR_WIDTH     (AxiCfgAddrDownsized.AddrWidth),
      .AXI_DATA_WIDTH     (AxiCfgAddrDownsized.DataWidth),
      .AXI_ID_WIDTH       (AxiCfgAddrDownsized.OutIdWidth),
      .AXI_USER_WIDTH     (AxiCfgAddrDownsized.UserWidth),
      .AXI_MAX_WRITE_TXNS (AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
      .AXI_MAX_READ_TXNS  (AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
      .FALL_THROUGH       (1'b0),
      .FULL_BW            (0)
    ) i_axi_to_axi_lite_tg_tile_cfg (
      .clk_i,
      .rst_ni,
      .testmode_i (test_enable_i),
      .slv        (axi_tg_tile_cfg_addr_downsized[i]),
      .mst        (axi_lite_tile_tg_cfg[i])
    );
  end

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_realm_wide_cfg_req, axi_lite_tile_tg_cfg[0])
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tile_tg_cfg[0], axi_lite_realm_wide_cfg_rsp)

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_read_cfg_req, axi_lite_tile_tg_cfg[1])
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tile_tg_cfg[1], axi_lite_read_cfg_rsp)

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_write_cfg_req, axi_lite_tile_tg_cfg[2])
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tile_tg_cfg[2], axi_lite_write_cfg_rsp)

  `AXI_LITE_ASSIGN_TO_REQ(axi_lite_comp_cfg_req, axi_lite_tile_tg_cfg[3])
  `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tile_tg_cfg[3], axi_lite_comp_cfg_rsp)

  ///////////////
  // AXI-Realm //
  ///////////////

  // `REG_BUS_TYPEDEF_ALL(cfg, addr_t, reg_data_t, reg_strb_t)

  // TO DO: Make it parameterizable on the number of tile managers
  floo_picobello_noc_pkg::axi_wide_in_req_t axi_realm_wide_in_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t axi_realm_wide_in_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t axi_realm_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_realm_wide_out_rsp;

  // Register bus signals
  cfg_req_t reg_realm_wide_cfg_req; 
  cfg_rsp_t reg_realm_wide_cfg_rsp;

  // AXI RT IDs
  slv_id_t reg_cfg_rt_wide_id;

  // Convert AXI4-Lite to custom register interface for the RT wide configuration bus
  axi_lite_to_reg #(
    .ADDR_WIDTH     (AxiCfgAddrDownsized.AddrWidth),
    .DATA_WIDTH     (AxiCfgAddrDownsized.DataWidth),
    .BUFFER_DEPTH   (2),
    .DECOUPLE_W     (1),
    .axi_lite_req_t (axi_lite_host_req_t),
    .axi_lite_rsp_t (axi_lite_host_rsp_t),
    .reg_req_t      (cfg_req_t),
    .reg_rsp_t      (cfg_rsp_t)
  ) i_axi_lite_to_reg_wide (
    .clk_i,
    .rst_ni,
    .axi_lite_req_i (axi_lite_realm_wide_cfg_req),
    .axi_lite_rsp_o (axi_lite_realm_wide_cfg_rsp),
    .reg_req_o      (reg_realm_wide_cfg_req),
    .reg_rsp_i      (reg_realm_wide_cfg_rsp)
  );

  // AXI RT unit wide
  axi_rt_unit_top #(
    .NumManagers      ( NumCores                  ),
    .AddrWidth        ( AxiCfgW.AddrWidth         ),
    .DataWidth        ( AxiCfgW.DataWidth         ),
    .IdWidth          ( AxiCfgW.OutIdWidth        ),
    .UserWidth        ( AxiCfgW.UserWidth         ),
    .NumPending       ( NumPending                ),
    .WBufferDepth     ( WBufferDepth              ),
    .NumAddrRegions   ( NumRegions                ),
    .BudgetWidth      ( BudgetWidth               ),
    .PeriodWidth      ( PeriodWidth               ),
    .RegIdWidth       ( AxiSlvIdWidth             ),
    .CutDecErrors     ( 1'b0                      ),
    .CutSplitterPaths ( 1'b0                      ),
    .aw_chan_t        ( axi_wide_in_aw_chan_t     ),
    .ar_chan_t        ( axi_wide_in_ar_chan_t     ),
    .w_chan_t         ( axi_wide_in_w_chan_t      ),
    .r_chan_t         ( axi_wide_in_r_chan_t      ),
    .b_chan_t         ( axi_wide_in_b_chan_t      ),
    .axi_req_t        ( axi_wide_in_req_t         ),
    .axi_resp_t       ( axi_wide_in_rsp_t         ),
    .req_req_t        ( cfg_req_t                 ),
    .req_rsp_t        ( cfg_rsp_t                 )
  ) i_axi_rt_unit_wide (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( axi_realm_wide_in_req     ), // as soon as more masters are added, use an array of master ports
    .slv_resp_o       ( axi_realm_wide_in_rsp     ), // as soon as more masters are added, use an array of master ports
    .mst_req_o        ( axi_realm_wide_out_req    ), 
    .mst_resp_i       ( axi_realm_wide_out_rsp    ), 
    .reg_req_i        ( reg_realm_wide_cfg_req    ), 
    .reg_rsp_o        ( reg_realm_wide_cfg_rsp    ), 
    .reg_id_i         ( reg_cfg_rt_wide_id        )  
  );

  assign reg_cfg_rt_wide_id = id_i.y + MeshDim.y * id_i.x;

  // Synthetic traffic
  `AXI_ASSIGN_REQ_STRUCT(chimney_wide_in_req, axi_realm_wide_out_req);
  `AXI_ASSIGN_RESP_STRUCT(axi_realm_wide_out_rsp, chimney_wide_in_rsp);

  ///////////////////////
  // Traffic Generator //
  ///////////////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgW.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgW.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgW.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgW.UserWidth)
  ) axi_tg_wide_out();

  // Output data traffic
  floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_rsp;

  // Input programming
  floo_picobello_noc_pkg::axi_narrow_in_req_t axi_tg_cfg_req_i;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t axi_tg_cfg_rsp_o;

  floo_picobello_noc_pkg::axi_narrow_in_req_t axi_tg_cfg_cut_req_i;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t axi_tg_cfg_cut_rsp_o;

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_read_cfg();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_write_cfg();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_comp_cfg();

  `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_read_cfg, axi_lite_read_cfg_req)
  `AXI_LITE_ASSIGN_TO_RESP(axi_lite_read_cfg_rsp, axi_lite_read_cfg)

  `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_write_cfg, axi_lite_write_cfg_req)
  `AXI_LITE_ASSIGN_TO_RESP(axi_lite_write_cfg_rsp, axi_lite_write_cfg)

  `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_comp_cfg, axi_lite_comp_cfg_req)
  `AXI_LITE_ASSIGN_TO_RESP(axi_lite_comp_cfg_rsp, axi_lite_comp_cfg)
  
  axi_hls_tg_rw_wrapper #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgW.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgW.DataWidth),
    .AXI_ID_WIDTH (floo_picobello_noc_pkg::AxiCfgW.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgW.UserWidth),
    .AXI_LOCK (1),
    .AXI_LITE_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_LITE_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) i_axi_hls_tg_wrapper (
    .clk_i,
    .rst_ni,
    .axi_tg_wide_out,
    .axi_lite_read_cfg,
    .axi_lite_write_cfg,
    .axi_lite_comp_cfg
  );

  `AXI_ASSIGN_TO_REQ(axi_tg_wide_out_req, axi_tg_wide_out)
  `AXI_ASSIGN_FROM_RESP(axi_tg_wide_out, axi_tg_wide_out_rsp)

  // Synthetic traffic
  `AXI_ASSIGN_REQ_STRUCT(axi_realm_wide_in_req, axi_tg_wide_out_req)
  `AXI_ASSIGN_RESP_STRUCT(axi_tg_wide_out_rsp, axi_realm_wide_in_rsp)

  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (NumCores < NumCoresMax) else $fatal(1, "Wrong number of cores");
  end
  `endif
  // pragma translate_on
endmodule
