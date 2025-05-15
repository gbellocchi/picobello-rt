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
(
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

  localparam chimney_cfg_t ChimneyCfgN = floo_pkg::ChimneyDefaultCfg;
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
    .axi_narrow_in_req_i (chimney_narrow_in_req),
    .axi_narrow_in_rsp_o (chimney_narrow_in_rsp),
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

  /////////////////////////////////////////////
  // Route AXI4 narrow inputs to destination //
  /////////////////////////////////////////////

  // Narrow inputs must be re-routed for:
  // - AXI-Realm configuration for narrow port (from the Host processor)
  // - AXI-Realm configuration for wide port (from the Host processor)
  // - Traffic generator configuration (from the Host processor)

  // Number of partitions
  localparam int unsigned NumTgTileCfg = 3;

  // AXI4 interfaces - tile input partitions
  floo_picobello_noc_pkg::axi_narrow_out_req_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_rsp;

  // AXI4 interfaces - tile input partitions (data downsized)
  fpga_picobello_pkg::axi_narrow_out_data_downsized_req_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_req_i_data_downsized;
  fpga_picobello_pkg::axi_narrow_out_data_downsized_rsp_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_rsp_o_data_downsized;

  // AXI4 interfaces - tile input partitions (address downsized)
  fpga_picobello_pkg::axi_narrow_out_addr_downsized_req_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_req_i_addr_downsized;
  fpga_picobello_pkg::axi_narrow_out_addr_downsized_rsp_t [NumTgTileCfg-1:0] axi_tg_tile_cfg_rsp_o_addr_downsized;

  // AXI4-Lite interfaces - tile input partitions
  axi_lite_host_req_t [NumTgTileCfg-1:0] axi_lite_tile_tg_cfg_req_i;
  axi_lite_host_rsp_t [NumTgTileCfg-1:0] axi_lite_tile_tg_cfg_rsp_o;

  // AXI4-Lite interfaces - AXI-Realm narrow port configuration
  axi_lite_host_req_t  axi_lite_rt_narrow_cfg_req;
  axi_lite_host_rsp_t  axi_lite_rt_narrow_cfg_rsp;

  // AXI4-Lite interfaces - AXI-Realm narrow port configuration
  axi_lite_host_req_t  axi_lite_rt_wide_cfg_req;
  axi_lite_host_rsp_t  axi_lite_rt_wide_cfg_rsp;

  // AXI4-Lite interfaces - traffic generator configuration
  axi_lite_host_req_t  axi_lite_tg_cfg_req;
  axi_lite_host_rsp_t  axi_lite_tg_cfg_rsp;

  // Address map
  axi_pkg::xbar_rule_64_t [NumTgTileCfg-1:0] tg_cfg_in_addr_map;

  logic [AxiCfgN.AddrWidth-1:0] tile_partition_len; 
  assign tile_partition_len = 64'h0000_2000;

  localparam axi_pkg::xbar_cfg_t PicobelloTgXbarCfg = '{
    NoSlvPorts:         1,
    NoMstPorts:         NumTgTileCfg,
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
    NoAddrRules:        NumTgTileCfg
  };

  // AXI-Realm narrow configuration
  assign tg_cfg_in_addr_map[0] = '{
    idx:        0,
    start_addr: tg_base_addr_i,
    end_addr:   tg_base_addr_i + 1 * tile_partition_len
  }; 

  // AXI-Realm wide configuration
  assign tg_cfg_in_addr_map[1] = '{
    idx:        1,
    start_addr: tg_base_addr_i + 1 * tile_partition_len,
    end_addr:   tg_base_addr_i + 2 * tile_partition_len
  }; 

  // Traffic generator configuration
  assign tg_cfg_in_addr_map[2] = '{
    idx:        2,
    start_addr: tg_base_addr_i + 2 * tile_partition_len,
    end_addr:   tg_base_addr_i + 3 * tile_partition_len
  };

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgN.UserWidth)
  ) chimney_narrow_out[0:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgN.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgN.UserWidth)
  ) axi_tg_tile_cfg [NumTgTileCfg-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgDataDownsized.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgDataDownsized.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgDataDownsized.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgDataDownsized.UserWidth)
  ) axi_tg_tile_cfg_data_downsized [NumTgTileCfg-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AxiCfgAddrDownsized.AddrWidth),
    .AXI_DATA_WIDTH (AxiCfgAddrDownsized.DataWidth),
    .AXI_ID_WIDTH   (AxiCfgAddrDownsized.OutIdWidth),
    .AXI_USER_WIDTH (AxiCfgAddrDownsized.UserWidth)
  ) axi_tg_tile_cfg_addr_downsized [NumTgTileCfg-1:0]();

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_tile_tg_cfg [NumTgTileCfg-1:0]();

  `AXI_ASSIGN_FROM_REQ(chimney_narrow_out[0], chimney_narrow_out_req)
  `AXI_ASSIGN_TO_RESP(chimney_narrow_out_rsp, chimney_narrow_out[0])

  // axi_xbar #(
  //   .Cfg            (PicobelloTgXbarCfg),
  //   .ATOPs          (1'b1),
  //   .Connectivity   ('1),
  //   .slv_aw_chan_t  (floo_picobello_noc_pkg::axi_narrow_out_aw_chan_t),
  //   .mst_aw_chan_t  (floo_picobello_noc_pkg::axi_narrow_out_aw_chan_t),
  //   .w_chan_t       (floo_picobello_noc_pkg::axi_narrow_out_w_chan_t),
  //   .slv_b_chan_t   (floo_picobello_noc_pkg::axi_narrow_out_b_chan_t),
  //   .mst_b_chan_t   (floo_picobello_noc_pkg::axi_narrow_out_b_chan_t),
  //   .slv_ar_chan_t  (floo_picobello_noc_pkg::axi_narrow_out_ar_chan_t),
  //   .mst_ar_chan_t  (floo_picobello_noc_pkg::axi_narrow_out_ar_chan_t),
  //   .slv_r_chan_t   (floo_picobello_noc_pkg::axi_narrow_out_r_chan_t),
  //   .mst_r_chan_t   (floo_picobello_noc_pkg::axi_narrow_out_r_chan_t),
  //   .slv_req_t      (floo_picobello_noc_pkg::axi_narrow_out_req_t),
  //   .slv_resp_t     (floo_picobello_noc_pkg::axi_narrow_out_rsp_t),
  //   .mst_req_t      (floo_picobello_noc_pkg::axi_narrow_out_req_t),
  //   .mst_resp_t     (floo_picobello_noc_pkg::axi_narrow_out_rsp_t),
  //   .rule_t         (axi_pkg::xbar_rule_64_t)
  // ) i_tg_tile_cfg_xbar (
  //   .clk_i                  (clk_i),
  //   .rst_ni                 (rst_ni),
  //   .test_i                 (test_enable_i),
  //   .slv_ports_req_i        (chimney_narrow_out_req),
  //   .slv_ports_resp_o       (chimney_narrow_out_rsp),
  //   .mst_ports_req_o        (axi_tg_tile_cfg_req),
  //   .mst_ports_resp_i       (axi_tg_tile_cfg_rsp),
  //   .addr_map_i             (tg_cfg_in_addr_map),
  //   .en_default_mst_port_i  ('0),
  //   .default_mst_port_i     ('0)
  // );

  axi_xbar_intf #(
    .AXI_USER_WIDTH (),
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

  for (genvar i = 0; i < NumTgTileCfg; i++) begin : gen_tg_tile_cfg_axi_lite

    // `AXI_ASSIGN_FROM_REQ(axi_tg_tile_cfg[i], axi_tg_tile_cfg_req[i])
    // `AXI_ASSIGN_TO_RESP(axi_tg_tile_cfg_rsp[i], axi_tg_tile_cfg[i])

    // axi_dw_converter #(
    //   .AxiMaxReads        (8),
    //   .AxiSlvPortDataWidth(AxiCfgN.DataWidth),
    //   .AxiMstPortDataWidth(AxiCfgDataDownsized.DataWidth),
    //   .AxiAddrWidth       (AxiCfgDataDownsized.AddrWidth),
    //   .AxiIdWidth         (AxiCfgDataDownsized.OutIdWidth),
    //   .aw_chan_t          (axi_narrow_out_aw_chan_t),
    //   .mst_w_chan_t       (axi_narrow_out_data_downsized_w_chan_t),
    //   .slv_w_chan_t       (axi_narrow_out_w_chan_t),
    //   .b_chan_t           (axi_narrow_out_b_chan_t),
    //   .ar_chan_t          (axi_narrow_out_ar_chan_t),
    //   .mst_r_chan_t       (axi_narrow_out_data_downsized_r_chan_t),
    //   .slv_r_chan_t       (axi_narrow_out_r_chan_t),
    //   .axi_mst_req_t      (axi_narrow_out_data_downsized_req_t),
    //   .axi_mst_resp_t     (axi_narrow_out_data_downsized_rsp_t),
    //   .axi_slv_req_t      (axi_narrow_out_req_t),
    //   .axi_slv_resp_t     (axi_narrow_out_rsp_t)
    // ) i_axi_dw_converter_tg_tile_cfg (
    //   .clk_i      (clk_i),
    //   .rst_ni     (rst_ni),
    //   .slv_req_i  (axi_tg_tile_cfg_req[i]),
    //   .slv_resp_o (axi_tg_tile_cfg_rsp[i]),
    //   .mst_req_o  (axi_tg_tile_cfg_req_i_data_downsized[i]),
    //   .mst_resp_i (axi_tg_tile_cfg_rsp_o_data_downsized[i])
    // );

    // axi_modify_address #(
    //   .slv_req_t  (axi_narrow_out_data_downsized_req_t),
    //   .mst_addr_t (axi_narrow_out_addr_downsized_addr_t),
    //   .mst_req_t  (axi_narrow_out_addr_downsized_req_t),
    //   .axi_resp_t (axi_narrow_out_addr_downsized_rsp_t)
    // ) i_axi_modify_address (
    //   .slv_req_i     (axi_tg_tile_cfg_req_i_data_downsized[i]),
    //   .slv_resp_o    (axi_tg_tile_cfg_rsp_o_data_downsized[i]),
    //   .mst_req_o     (axi_tg_tile_cfg_req_i_addr_downsized[i]),
    //   .mst_resp_i    (axi_tg_tile_cfg_rsp_o_addr_downsized[i]),
    //   .mst_aw_addr_i (axi_tg_tile_cfg_req_i_data_downsized[i].aw.addr[31:0]),
    //   .mst_ar_addr_i (axi_tg_tile_cfg_req_i_data_downsized[i].ar.addr[31:0])
    // );

    axi_dw_converter_intf #(
      .AXI_ID_WIDTH             (AxiCfgDataDownsized.OutIdWidth),
      .AXI_ADDR_WIDTH           (AxiCfgDataDownsized.AddrWidth),
      .AXI_SLV_PORT_DATA_WIDTH  (AxiCfgN.DataWidth),
      .AXI_MST_PORT_DATA_WIDTH  (AxiCfgDataDownsized.DataWidth),
      .AXI_USER_WIDTH           (AxiCfgN.UserWidth),
      .AXI_MAX_READS            (8)
    ) i_axi_data_converter_tg_tile_cfg (
      .clk_i,
      .rst_ni,
      .slv    (axi_tg_tile_cfg[i]),
      .mst    (axi_tg_tile_cfg_data_downsized[i])
    );

    axi_modify_address_intf #(
      .AXI_SLV_PORT_ADDR_WIDTH  (AxiCfgDataDownsized.AddrWidth),
      .AXI_MST_PORT_ADDR_WIDTH  (AxiCfgAddrDownsized.AddrWidth),
      .AXI_DATA_WIDTH           (AxiCfgAddrDownsized.DataWidth),
      .AXI_ID_WIDTH             (AxiCfgAddrDownsized.OutIdWidth),
      .AXI_USER_WIDTH           (AxiCfgAddrDownsized.UserWidth)
    ) i_axi_addr_converter_tg_tile_cfg (
      .slv            (axi_tg_tile_cfg_data_downsized[i]),
      .mst_aw_addr_i  (axi_tg_tile_cfg_addr_downsized[i].aw_addr[31:0]),
      .mst_ar_addr_i  (axi_tg_tile_cfg_addr_downsized[i].aw_addr[31:0]),
      .mst            (axi_tg_tile_cfg_addr_downsized[i])
    );

    // axi_to_axi_lite #(
    //   .AxiAddrWidth    (AxiCfgAddrDownsized.AddrWidth),
    //   .AxiDataWidth    (AxiCfgAddrDownsized.DataWidth),
    //   .AxiIdWidth      (AxiCfgAddrDownsized.OutIdWidth),
    //   .AxiUserWidth    (AxiCfgAddrDownsized.UserWidth),
    //   .AxiMaxWriteTxns (AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
    //   .AxiMaxReadTxns  (AxiCfgAddrDownsized.DataWidth/AxiLiteCfg.DataWidth),
    //   .FallThrough     (1'b0),
    //   .FullBW          (0),
    //   .full_req_t      (axi_narrow_out_addr_downsized_req_t),
    //   .full_resp_t     (axi_narrow_out_addr_downsized_rsp_t),
    //   .lite_req_t      (axi_lite_host_req_t),
    //   .lite_resp_t     (axi_lite_host_rsp_t)
    // ) i_axi_to_axi_lite_tg_tile_cfg (
    //   .clk_i      (clk_i),
    //   .rst_ni     (rst_ni),
    //   .test_i     (test_enable_i),
    //   .slv_req_i  (axi_tg_tile_cfg_req_i_addr_downsized[i]),
    //   .slv_resp_o (axi_tg_tile_cfg_rsp_o_addr_downsized[i]),
    //   .mst_req_o  (axi_lite_tile_tg_cfg_req_i[i]),
    //   .mst_resp_i (axi_lite_tile_tg_cfg_rsp_o[i])
    // );

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

    `AXI_LITE_ASSIGN_TO_REQ(axi_lite_tile_tg_cfg_req_i[i], axi_lite_tile_tg_cfg[i])
    `AXI_LITE_ASSIGN_FROM_RESP(axi_lite_tile_tg_cfg[i], axi_lite_tile_tg_cfg_rsp_o[i])

    // `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_tile_tg_cfg[i], axi_lite_tile_tg_cfg_req_i[i])
    // `AXI_LITE_ASSIGN_TO_RESP(axi_lite_tile_tg_cfg_rsp_o[i], axi_lite_tile_tg_cfg[i])
  end

  `AXI_LITE_ASSIGN_REQ_STRUCT(axi_lite_rt_narrow_cfg_req, axi_lite_tile_tg_cfg_req_i[0])
  `AXI_LITE_ASSIGN_RESP_STRUCT(axi_lite_tile_tg_cfg_rsp_o[0], axi_lite_rt_narrow_cfg_rsp)

  `AXI_LITE_ASSIGN_REQ_STRUCT(axi_lite_rt_wide_cfg_req, axi_lite_tile_tg_cfg_req_i[1])
  `AXI_LITE_ASSIGN_RESP_STRUCT(axi_lite_tile_tg_cfg_rsp_o[1], axi_lite_rt_wide_cfg_rsp)

  `AXI_LITE_ASSIGN_REQ_STRUCT(axi_lite_tg_cfg_req, axi_lite_tile_tg_cfg_req_i[2])
  `AXI_LITE_ASSIGN_RESP_STRUCT(axi_lite_tile_tg_cfg_rsp_o[2], axi_lite_tg_cfg_rsp)

  ///////////////
  // AXI-Realm //
  ///////////////

  // Number of masters
  localparam int unsigned NumMasters    = 32'd1;
  // Number of slaves
  localparam int unsigned NumSlaves     = 32'd1;
  // Number of regions per master
  localparam int unsigned NumRegions    = 32'd2;
  // Number of outstanding Transactions
  localparam int unsigned NumPending    = 32'd4;
  // Depth of the Buffer
  localparam int unsigned WBufferDepth  = 32'd16;
  // RT unit parameters
  localparam int unsigned PeriodWidth = 32'd32;
  localparam int unsigned BudgetWidth = 32'd32;
  // Slave ID
  localparam int unsigned AxiSlvIdWidth = (NumMasters == 32'd1 & NumSlaves == 32'd1) ?
                                            AxiCfgN.OutIdWidth :
                                            AxiCfgN.OutIdWidth + cf_math_pkg::idx_width(NumMasters);

  // rule type
  typedef struct packed {
    logic [7:0] idx;
    axi_narrow_in_addr_t start_addr;
    axi_narrow_in_addr_t end_addr;
  } rt_rule_t;

  typedef logic [AxiSlvIdWidth-1 :0] slv_id_t;

  floo_picobello_noc_pkg::axi_narrow_in_req_t axi_rt_narrow_in_req;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t axi_rt_narrow_in_rsp;
  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_rt_narrow_out_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_rt_narrow_out_rsp;

  floo_picobello_noc_pkg::axi_wide_in_req_t axi_rt_wide_in_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t axi_rt_wide_in_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t axi_rt_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_rt_wide_out_rsp;

  // // AXI4-Lite bus signals
  // axi_lite_host_req_t axi_rt_narrow_lite_req, axi_rt_wide_lite_req;
  // axi_lite_host_rsp_t axi_rt_narrow_lite_rsp, axi_rt_wide_lite_rsp;

  // Register bus signals
  cfg_req_t reg_cfg_rt_narrow_req, reg_cfg_rt_wide_req;
  cfg_rsp_t reg_cfg_rt_narrow_rsp, reg_cfg_rt_wide_rsp;

  // AXI RT IDs
  slv_id_t reg_cfg_rt_narrow_id, reg_cfg_rt_wide_id;

  // Convert AXI Lite to custom register interface fr RT configuration bus
  axi_lite_to_reg #(
    .ADDR_WIDTH   (AxiLiteCfg.AddrWidth),
    .DATA_WIDTH   (AxiLiteCfg.DataWidth),
    .BUFFER_DEPTH (2),
    .DECOUPLE_W   (1),
    .axi_lite_req_t (axi_lite_host_req_t),
    .axi_lite_rsp_t (axi_lite_host_rsp_t),
    .reg_req_t (cfg_req_t),
    .reg_rsp_t (cfg_rsp_t)
  ) i_axi_lite_to_reg_narrow (
    .clk_i,
    .rst_ni,
    .axi_lite_req_i (axi_lite_rt_narrow_cfg_req),
    .axi_lite_rsp_o (axi_lite_rt_narrow_cfg_rsp),
    .reg_req_o      (reg_cfg_rt_narrow_req),
    .reg_rsp_i      (reg_cfg_rt_narrow_rsp)
  );

  axi_lite_to_reg #(
    .ADDR_WIDTH   (AxiLiteCfg.AddrWidth),
    .DATA_WIDTH   (AxiLiteCfg.DataWidth),
    .BUFFER_DEPTH (2),
    .DECOUPLE_W   (1),
    .axi_lite_req_t (axi_lite_host_req_t),
    .axi_lite_rsp_t (axi_lite_host_rsp_t),
    .reg_req_t (cfg_req_t),
    .reg_rsp_t (cfg_rsp_t)
  ) i_axi_lite_to_reg_wide (
    .clk_i,
    .rst_ni,
    .axi_lite_req_i (axi_lite_rt_wide_cfg_req),
    .axi_lite_rsp_o (axi_lite_rt_wide_cfg_rsp),
    .reg_req_o      (reg_cfg_rt_wide_req),
    .reg_rsp_i      (reg_cfg_rt_wide_rsp)
  );

  // AXI RT units
  axi_rt_unit_top #(
    .NumManagers      ( NumMasters                ),
    .AddrWidth        ( AxiCfgN.AddrWidth         ),
    .DataWidth        ( AxiCfgN.DataWidth         ),
    .IdWidth          ( AxiCfgN.UserWidth         ),
    .UserWidth        ( AxiCfgN.OutIdWidth        ),
    .NumPending       ( NumPending                ),
    .WBufferDepth     ( WBufferDepth              ),
    .NumAddrRegions   ( NumRegions                ),
    .BudgetWidth      ( BudgetWidth               ),
    .PeriodWidth      ( PeriodWidth               ),
    .RegIdWidth       ( AxiSlvIdWidth             ),
    .CutDecErrors     ( 1'b0                      ),
    .CutSplitterPaths ( 1'b0                      ),
    .aw_chan_t        ( axi_narrow_in_aw_chan_t   ),
    .ar_chan_t        ( axi_narrow_in_ar_chan_t   ),
    .w_chan_t         ( axi_narrow_in_w_chan_t    ),
    .r_chan_t         ( axi_narrow_in_b_chan_t    ),
    .b_chan_t         ( axi_narrow_in_r_chan_t    ),
    .axi_req_t        ( axi_narrow_in_req_t       ),
    .axi_resp_t       ( axi_narrow_in_rsp_t       ),
    .req_req_t        ( cfg_req_t                 ),
    .req_rsp_t        ( cfg_rsp_t                 )
  ) i_axi_rt_unit_narrow (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( axi_rt_narrow_in_req      ),
    .slv_resp_o       ( axi_rt_narrow_in_rsp      ),
    .mst_req_o        ( axi_rt_narrow_out_req     ),
    .mst_resp_i       ( axi_rt_narrow_out_rsp     ),
    .reg_req_i        ( reg_cfg_rt_narrow_req     ),
    .reg_rsp_o        ( reg_cfg_rt_narrow_rsp     ),
    .reg_id_i         ( reg_cfg_rt_narrow_id      )
  );

  axi_rt_unit_top #(
    .NumManagers      ( NumMasters                ),
    .AddrWidth        ( AxiCfgN.AddrWidth         ),
    .DataWidth        ( AxiCfgN.DataWidth         ),
    .IdWidth          ( AxiCfgN.UserWidth         ),
    .UserWidth        ( AxiCfgN.OutIdWidth        ),
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
    .r_chan_t         ( axi_wide_in_b_chan_t      ),
    .b_chan_t         ( axi_wide_in_r_chan_t      ),
    .axi_req_t        ( axi_wide_in_req_t         ),
    .axi_resp_t       ( axi_wide_in_rsp_t         ),
    .req_req_t        ( cfg_req_t                 ),
    .req_rsp_t        ( cfg_rsp_t                 )
  ) i_axi_rt_unit_wide (
    .clk_i,
    .rst_ni,
    .slv_req_i        ( axi_rt_wide_in_req        ),
    .slv_resp_o       ( axi_rt_wide_in_rsp        ),
    .mst_req_o        ( axi_rt_wide_out_req       ),
    .mst_resp_i       ( axi_rt_wide_out_rsp       ),
    .reg_req_i        ( reg_cfg_rt_wide_req       ),
    .reg_rsp_o        ( reg_cfg_rt_wide_rsp       ),
    .reg_id_i         ( reg_cfg_rt_wide_id        )  
  );

  assign reg_cfg_rt_narrow_id = id_i.y + MeshDim.x * id_i.x;
  assign reg_cfg_rt_wide_id = id_i.y + MeshDim.x * id_i.x;

  // Synthetic traffic
  `AXI_ASSIGN_REQ_STRUCT(chimney_narrow_in_req, axi_rt_narrow_out_req);
  `AXI_ASSIGN_RESP_STRUCT(axi_rt_narrow_out_rsp, chimney_narrow_in_rsp);

  `AXI_ASSIGN_REQ_STRUCT(chimney_wide_in_req, axi_rt_wide_out_req);
  `AXI_ASSIGN_RESP_STRUCT(axi_rt_wide_out_rsp, chimney_wide_in_rsp);

  ///////////////////////
  // Traffic Generator //
  ///////////////////////

  // Output data traffic
  floo_picobello_noc_pkg::axi_narrow_out_req_t axi_tg_narrow_out_req;
  floo_picobello_noc_pkg::axi_narrow_out_rsp_t axi_tg_narrow_out_rsp;
  floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_rsp;

  // Input programming
  floo_picobello_noc_pkg::axi_narrow_in_req_t axi_tg_cfg_req_i;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t axi_tg_cfg_rsp_o;

  floo_picobello_noc_pkg::axi_narrow_in_req_t axi_tg_cfg_cut_req_i;
  floo_picobello_noc_pkg::axi_narrow_in_rsp_t axi_tg_cfg_cut_rsp_o;

  // axi_lite_host_req_t axi_lite_tg_cfg_req_i;
  // axi_lite_host_rsp_t axi_lite_tg_cfg_rsp_o;

  AXI_LITE #(
    .AXI_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) axi_lite_tg_cfg();

  // axi_cut #(
  //   .Bypass     (1'b0),
  //   .aw_chan_t  (floo_picobello_noc_pkg::axi_narrow_in_aw_chan_t),
  //   .w_chan_t   (floo_picobello_noc_pkg::axi_narrow_in_w_chan_t),
  //   .b_chan_t   (floo_picobello_noc_pkg::axi_narrow_in_b_chan_t),
  //   .ar_chan_t  (floo_picobello_noc_pkg::axi_narrow_in_ar_chan_t),
  //   .r_chan_t   (floo_picobello_noc_pkg::axi_narrow_in_r_chan_t),
  //   .axi_req_t  (floo_picobello_noc_pkg::axi_narrow_in_req_t),
  //   .axi_resp_t (floo_picobello_noc_pkg::axi_narrow_in_rsp_t)
  // ) i_axi_cut (
  //   .clk_i,
  //   .rst_ni,
  //   .slv_req_i  (axi_tg_cfg_req_i),
  //   .slv_resp_o (axi_tg_cfg_rsp_o),
  //   .mst_req_o  (axi_tg_cfg_cut_req_i),
  //   .mst_resp_i (axi_tg_cfg_cut_rsp_o)
  // );

  // axi_to_axi_lite #(
  //   .AxiAddrWidth    (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
  //   .AxiDataWidth    (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
  //   .AxiIdWidth      (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
  //   .AxiUserWidth    (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
  //   .AxiMaxWriteTxns (floo_picobello_noc_pkg::AxiCfgN.DataWidth/AxiLiteCfg.DataWidth),
  //   .AxiMaxReadTxns  (floo_picobello_noc_pkg::AxiCfgN.DataWidth/AxiLiteCfg.DataWidth),
  //   .FallThrough     (1'b0),
  //   .FullBW          (0),
  //   .full_req_t      (floo_picobello_noc_pkg::axi_narrow_in_req_t),
  //   .full_resp_t     (floo_picobello_noc_pkg::axi_narrow_in_rsp_t),
  //   .lite_req_t      (axi_lite_host_req_t),
  //   .lite_resp_t     (axi_lite_host_rsp_t)
  // ) i_axi_to_axi_lite (
  //   .clk_i      (clk_i),
  //   .rst_ni     (rst_ni),
  //   .test_i     (test_enable_i),
  //   .slv_req_i  (axi_tg_cfg_cut_req_i),
  //   .slv_resp_o (axi_tg_cfg_cut_rsp_o),
  //   .mst_req_o  (axi_lite_tg_cfg_req_i),
  //   .mst_resp_i (axi_lite_tg_cfg_rsp_o)
  // );

  `AXI_LITE_ASSIGN_FROM_REQ(axi_lite_tg_cfg, axi_lite_tg_cfg_req)
  `AXI_LITE_ASSIGN_TO_RESP(axi_lite_tg_cfg_rsp, axi_lite_tg_cfg)
  
  axi_hls_tg_wrapper #(
    .AXI_ADDR_WIDTH (floo_picobello_noc_pkg::AxiCfgN.AddrWidth),
    .AXI_DATA_WIDTH (floo_picobello_noc_pkg::AxiCfgN.DataWidth),
    .AXI_ID_WIDTH (floo_picobello_noc_pkg::AxiCfgN.OutIdWidth),
    .AXI_USER_WIDTH (floo_picobello_noc_pkg::AxiCfgN.UserWidth),
    .AXI_LOCK (1),
    .AXI_LITE_ADDR_WIDTH (AxiLiteCfg.AddrWidth),
    .AXI_LITE_DATA_WIDTH (AxiLiteCfg.DataWidth)
  ) i_axi_hls_tg_wrapper (
    .clk_i,
    .rst_ni,
    .axi_tg_narrow_out_req,
    .axi_tg_narrow_out_rsp,
    .axi_tg_wide_out_req,
    .axi_tg_wide_out_rsp,
    .axi_lite_tg_cfg
  );

  // Synthetic traffic
  `AXI_ASSIGN_REQ_STRUCT(axi_rt_narrow_in_req, axi_tg_narrow_out_req);
  `AXI_ASSIGN_RESP_STRUCT(axi_tg_narrow_out_rsp, axi_rt_narrow_in_rsp);
  `AXI_ASSIGN_REQ_STRUCT(axi_rt_wide_in_req, axi_tg_wide_out_req);
  `AXI_ASSIGN_RESP_STRUCT(axi_tg_wide_out_rsp, axi_rt_wide_in_rsp);

  // // Programming port
  // `AXI_ASSIGN_REQ_STRUCT(axi_tg_cfg_req_i, chimney_narrow_out_req);
  // `AXI_ASSIGN_RESP_STRUCT(chimney_narrow_out_rsp, axi_tg_cfg_rsp_o);

endmodule
