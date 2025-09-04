// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "common_cells/registers.svh"
`include "axi/assign.svh"
`include "axi/typedef.svh"

module fpga_l2_tile 
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;
  import picobello_pkg::*;
  import fpga_picobello_pkg::*;
(
  // Clocks and Resets
  input  logic                                    clk_i,
  input  logic                                    rst_ni,
  input  logic                                    test_enable_i,

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

  floo_picobello_noc_pkg::axi_wide_in_req_t chimney_wide_out_req;
  floo_picobello_noc_pkg::axi_wide_in_rsp_t chimney_wide_out_rsp;

  localparam chimney_cfg_t ChimneyCfgN = set_ports(ChimneyDefaultCfg, 1'b0, 1'b0);
  localparam chimney_cfg_t ChimneyCfgW = set_ports(ChimneyDefaultCfg, 1'b1, 1'b0);

  floo_nw_chimney #(
    .AxiCfgN             (floo_picobello_noc_pkg::AxiCfgN),
    .AxiCfgW             (floo_picobello_noc_pkg::AxiCfgW),
    .ChimneyCfgN         (ChimneyCfgN),
    .ChimneyCfgW         (ChimneyCfgW),
    .RouteCfg            (floo_picobello_noc_pkg::RouteCfg),
    .AtopSupport         (1'b0),
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
    .axi_narrow_out_req_o(),
    .axi_narrow_out_rsp_i('0),
    .axi_wide_in_req_i   ('0),
    .axi_wide_in_rsp_o   (),
    .axi_wide_out_req_o  (chimney_wide_out_req),
    .axi_wide_out_rsp_i  (chimney_wide_out_rsp),
    .floo_req_o          (router_floo_req_in[Eject]),
    .floo_rsp_o          (router_floo_rsp_in[Eject]),
    .floo_wide_o         (router_floo_wide_in[Eject]),
    .floo_req_i          (router_floo_req_out[Eject]),
    .floo_rsp_i          (router_floo_rsp_out[Eject]),
    .floo_wide_i         (router_floo_wide_out[Eject])
  );

  ///////////////
  // L2 memory //
  ///////////////

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( L2AddrWidth ),
    .AXI_DATA_WIDTH ( L2DataWidth ),
    .AXI_ID_WIDTH   ( L2IdWidth ),
    .AXI_USER_WIDTH ( L2UserWidth )
  ) axi_l2_slv();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( L2AddrWidth ),
    .AXI_DATA_WIDTH ( L2DataWidth ),
    .AXI_ID_WIDTH   ( L2IdWidth ),
    .AXI_USER_WIDTH ( L2UserWidth )
  ) axi_l2_slv_cut();

  // Types for entire memory array
  typedef logic [L2AddrWidth-1:0] arr_addr_t;
  typedef logic [L2DataWidth-1:0] arr_data_t;
  typedef logic [L2DataWidth/8-1:0] arr_strb_t;

  // Interface from AXI to memory array
  logic      l2_req, l2_req_q, l2_we;
  arr_addr_t l2_addr;
  arr_data_t l2_wdata, l2_rdata;
  arr_strb_t l2_be;

  `AXI_ASSIGN_FROM_REQ(axi_l2_slv, chimney_wide_out_req)
  `AXI_ASSIGN_TO_RESP(chimney_wide_out_rsp, axi_l2_slv)

  axi_cut_intf #(
    .BYPASS     ( 1'b0 ),
    .ADDR_WIDTH ( L2AddrWidth ),
    .DATA_WIDTH ( L2DataWidth ),
    .ID_WIDTH   ( L2IdWidth ),
    .USER_WIDTH ( L2UserWidth )
  ) i_l2_slv_cut (
    .clk_i,
    .rst_ni,
    .in     ( axi_l2_slv     ),
    .out    ( axi_l2_slv_cut )
  );

  axi2mem_wrap #(
    .AddrWidth  ( L2AddrWidth ),
    .DataWidth  ( L2DataWidth ),
    .IdWidth    ( L2IdWidth ),
    .UserWidth  ( L2UserWidth ),
    .NumBanks   ( 1 ),
    .BufDepth   ( 32 )
  ) i_axi2mem (
    .clk_i,
    .rst_ni,
    .busy_o       ( /* unused */   ),
    .slv          ( axi_l2_slv_cut ),
    .mem_req_o    ( l2_req         ),
    .mem_gnt_i    ( 1'b1           ),
    .mem_addr_o   ( l2_addr        ),
    .mem_wdata_o  ( l2_wdata       ),
    .mem_strb_o   ( l2_be          ),
    .mem_atop_o   ( /* unused */   ),
    .mem_we_o     ( l2_we          ),
    .mem_rvalid_i ( l2_req_q       ),
    .mem_rdata_i  ( l2_rdata       )
  );

`ifdef TARGET_XILINX
  // Synthesis for Xilinx FPGAs can optimize SRAM tiling itself.
  localparam NWords = picobello_pkg::MemTileSize / (L2DataWidth/8);
  localparam LineOff = $clog2(L2DataWidth/8);
  tc_sram #(
    .NumWords   ( NWords ), // specify explicitly for aegis!
    .DataWidth  ( L2DataWidth ), // specify explicitly for aegis!
    .ByteWidth  ( 8 ), // specify explicitly for aegis!
    .NumPorts   ( 1 )  // specify explicitly for aegis!
  ) i_tc_sram (
    .clk_i,
    .rst_ni,
    .req_i    ( l2_req                           ),
    .we_i     ( l2_we                            ),
    .addr_i   ( l2_addr[LineOff+:$clog2(NWords)] ), // SRAM is row-addressed
    .wdata_i  ( l2_wdata                         ),
    .be_i     ( l2_be                            ),
    .rdata_o  ( l2_rdata                         )
  );

`else
  // Properties of one memory cut, keep synchronized with instantiated macro.
  localparam int unsigned CutDw = 32;          // [bit], must l2_be a power of 2 and >=8
  localparam int unsigned CutNWords = 1024;   // must l2_be a power of 2
  localparam int unsigned CutNBits = CutDw * CutNWords; // = 32 * 1024 = 32768

  // Derived properties of memory array
  localparam int unsigned NParCuts = L2DataWidth / CutDw; // = 64 / 32 = 2
  localparam int unsigned ParCutsNBytes = NParCuts * CutNBits / 8; // = 2 * 32768 / 8 = 8192
  localparam int unsigned NSerCuts = picobello_pkg::MemTileSize / ParCutsNBytes; // = 131072 / 8192 = 16

  // Types for one memory cut
  typedef logic [$clog2(CutNWords)-1:0] cut_addr_t;
  typedef logic [CutDw-1:0]              cut_data_t;
  typedef logic [CutDw/8-1:0]            cut_strb_t;

  // Interface from memory array to memory cuts
  localparam int unsigned WordIdxOff = $clog2(L2DataWidth/8);
  localparam int unsigned WordIdxWidth = $clog2(CutNWords);
  localparam int unsigned RowIdxOff = WordIdxOff + WordIdxWidth;
  localparam int unsigned RowIdxWidth = $clog2(NSerCuts);
  logic       [NSerCuts-1:0]                  cut_req;
  cut_addr_t                                  cut_addr_d, cut_addr_q;
  cut_data_t  [NSerCuts-1:0][NParCuts-1:0]    cut_rdata;
  cut_data_t                  [NParCuts-1:0]  cut_wdata;
  cut_strb_t                  [NParCuts-1:0]  cut_be;

  assign cut_addr_d = l2_req ? l2_addr[RowIdxOff-1:WordIdxOff] : cut_addr_q;
  if (RowIdxWidth > 0) begin: gen_row_idx
    logic [RowIdxWidth-1:0]row_idx_d, row_idx_q;
    assign row_idx_d = l2_req ? l2_addr[RowIdxOff+:RowIdxWidth] : row_idx_q;
    always_comb begin
      cut_req = '0;
      cut_req[row_idx_d] = l2_req;
    end
    assign l2_rdata = cut_rdata[row_idx_q];
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        row_idx_q <= '0;
      end else begin
        row_idx_q <= row_idx_d;
      end
    end
  end else begin: gen_no_row_idx
    assign cut_req = l2_req;
    assign l2_rdata = cut_rdata;
  end
  assign cut_wdata = l2_wdata;
  assign cut_be = l2_be;

  for (genvar iRow = 0; iRow < NSerCuts; iRow++) begin: gen_rows
    for (genvar iCol = 0; iCol < NParCuts; iCol++) begin: gen_cols
      tc_sram #(
        .NumWords   ( CutNWords ), // specify explicitly for aegis!
        .DataWidth  ( CutDw      ), // specify explicitly for aegis!
        .ByteWidth  ( 8           ), // specify explicitly for aegis!
        .NumPorts   ( 1           )  // specify explicitly for aegis!
      ) i_tc_sram_cut (
        .clk_i,
        .rst_ni,
        .req_i    (cut_req[iRow]),
        .we_i     (l2_we),
        .addr_i   (cut_addr_d),
        .wdata_i  (cut_wdata[iCol]),
        .be_i     (cut_be[iCol]),
        .rdata_o  (cut_rdata[iRow][iCol])
      );
    end
  end

  `FFARN(cut_addr_q, cut_addr_d, '0, clk_i, rst_ni);
`endif

  `FFARN(l2_req_q, l2_req, 1'b0, clk_i, rst_ni);

  // Validate parameters and properties.
  // pragma translate_off
  initial begin
    assert (L2AddrWidth > 0);
    assert (L2AddrWidth % (2**$clog2(L2AddrWidth)) == 0);
    assert (L2DataWidth > 0);
    assert (L2DataWidth % (2**$clog2(L2DataWidth)) == 0);
    assert (picobello_pkg::MemTileSize > 0);
    assert (picobello_pkg::MemTileSize % (2**$clog2(picobello_pkg::MemTileSize)) == 0);
    assert (CutDw % (2**$clog2(CutDw)) == 0);
    assert (CutDw >= 8);
    assert (L2DataWidth >= CutDw);
    assert (CutNWords % 2**$clog2(CutNWords) == 0);
    assert (picobello_pkg::MemTileSize % ParCutsNBytes == 0);
  end
  // pragma translate_on

endmodule
