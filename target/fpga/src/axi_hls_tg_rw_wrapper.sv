// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_hls_tg_rw_wrapper #(
  parameter int unsigned  AXI_ADDR_WIDTH = 64,
  parameter int unsigned  AXI_DATA_WIDTH = 64,
  parameter int unsigned  AXI_ID_WIDTH = 1,
  parameter int unsigned  AXI_USER_WIDTH = 1,
  parameter int unsigned  AXI_LOCK = 1,
  parameter int unsigned  AXI_LITE_ADDR_WIDTH = 32,
  parameter int unsigned  AXI_LITE_DATA_WIDTH = 32
) (
    input logic             clk_i,
    input logic             rst_ni,
    // AXI4 wide
    AXI_BUS.Master          axi_tg_wide_out,
    // AXI4-Lite program
    AXI_LITE.Slave          axi_lite_read_cfg,
    AXI_LITE.Slave          axi_lite_write_cfg,
    AXI_LITE.Slave          axi_lite_comp_cfg
);  

    import floo_pkg::*;
    import floo_picobello_noc_pkg::*;
    import picobello_pkg::*;
    import fpga_picobello_pkg::*;

    AXI_BUS #(
        .AXI_ADDR_WIDTH (AxiCfgW.AddrWidth),
        .AXI_DATA_WIDTH (AxiCfgW.DataWidth),
        .AXI_ID_WIDTH   (AxiCfgW.OutIdWidth),
        .AXI_USER_WIDTH (AxiCfgW.UserWidth)
    ) axi_tg_wide_rw_out[1:0](); // 0: read, 1: write

    // Read generator
    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_r_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_r_rsp;

    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_r_read_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_r_read_rsp;

    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_r_write_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_r_write_rsp;

    // Write generator
    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_w_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_w_rsp;

    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_w_read_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_w_read_rsp;

    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_w_write_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_w_write_rsp;

    // Output
    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_out_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_out_rsp;

    // Output
    floo_picobello_noc_pkg::axi_wide_out_req_t axi_tg_wide_dummy_req;
    floo_picobello_noc_pkg::axi_wide_out_rsp_t axi_tg_wide_dummy_rsp;

    // Join read / write generators into output

    axi_rw_join #(
        .axi_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
        .axi_resp_t (floo_picobello_noc_pkg::axi_wide_out_rsp_t)
    ) i_rw_join_out (
        .clk_i,
        .rst_ni,
        // Read Slave
        .slv_read_req_i            ( axi_tg_wide_out_r_read_req      ),
        .slv_read_resp_o           ( axi_tg_wide_out_r_read_rsp      ),
        // Write Slave
        .slv_write_req_i           ( axi_tg_wide_out_w_write_req      ),
        .slv_write_resp_o          ( axi_tg_wide_out_w_write_rsp      ),
        // Read / Write Master
        .mst_req_o                 ( axi_tg_wide_out_req        ),
        .mst_resp_i                ( axi_tg_wide_out_rsp        )
    );

    `AXI_ASSIGN_FROM_REQ(axi_tg_wide_out, axi_tg_wide_out_req)
    `AXI_ASSIGN_TO_RESP(axi_tg_wide_out_rsp, axi_tg_wide_out)

    // Join read / write generators into dummy interfaces

    axi_rw_join #(
        .axi_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
        .axi_resp_t (floo_picobello_noc_pkg::axi_wide_out_rsp_t)
    ) i_rw_join_dummy (
        .clk_i,
        .rst_ni,
        // Read Slave
        .slv_read_req_i            ( axi_tg_wide_out_w_read_req      ),
        .slv_read_resp_o           ( axi_tg_wide_out_w_read_rsp      ),
        // Write Slave
        .slv_write_req_i           ( axi_tg_wide_out_r_write_req      ),
        .slv_write_resp_o          ( axi_tg_wide_out_r_write_rsp      ),
        // Read / Write Master
        .mst_req_o                 ( axi_tg_wide_dummy_req        ),
        .mst_resp_i                ( axi_tg_wide_dummy_rsp        )
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin : write_dummy_rsp_ff
        if (!rst_ni) begin
            axi_tg_wide_dummy_rsp.aw_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.w_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.b_valid <= 1'b0;
        end else
        if (axi_tg_wide_dummy_req.aw_valid == 1'b1) begin
            axi_tg_wide_dummy_rsp.aw_ready <= 1'b1;
            axi_tg_wide_dummy_rsp.w_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.b_valid <= 1'b0;
        end else
        if (axi_tg_wide_dummy_req.w_valid == 1'b1) begin
            axi_tg_wide_dummy_rsp.aw_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.w_ready <= 1'b1;
            axi_tg_wide_dummy_rsp.b_valid <= 1'b0;
        end else
        if (axi_tg_wide_dummy_req.b_ready == 1'b1) begin
            axi_tg_wide_dummy_rsp.aw_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.w_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.b_valid <= 1'b1;
        end 
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : read_dummy_rsp_ff
        if (!rst_ni) begin
            axi_tg_wide_dummy_rsp.ar_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.r_valid <= 1'b0;
        end else
        if (axi_tg_wide_dummy_req.ar_valid == 1'b1) begin
            axi_tg_wide_dummy_rsp.ar_ready <= 1'b1;
            axi_tg_wide_dummy_rsp.r_valid <= 1'b0;
        end else
        if (axi_tg_wide_dummy_req.r_ready == 1'b1) begin
            axi_tg_wide_dummy_rsp.ar_ready <= 1'b0;
            axi_tg_wide_dummy_rsp.r_valid <= 1'b1;
        end
    end

    // AXI4 TG - Wide Read

    `AXI_ASSIGN_TO_REQ(axi_tg_wide_out_r_req, axi_tg_wide_rw_out[0])
    `AXI_ASSIGN_FROM_RESP(axi_tg_wide_rw_out[0], axi_tg_wide_out_r_rsp)

    axi_rw_split #(
        .axi_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
        .axi_resp_t (floo_picobello_noc_pkg::axi_wide_out_rsp_t)
    ) i_r_split (
        .clk_i,
        .rst_ni,
        // Read / Write Slave
        .slv_req_i                 ( axi_tg_wide_out_r_req      ),
        .slv_resp_o                ( axi_tg_wide_out_r_rsp      ),
        // Read Master
        .mst_read_req_o            ( axi_tg_wide_out_r_read_req     ),
        .mst_read_resp_i           ( axi_tg_wide_out_r_read_rsp     ),
        // Write Master
        .mst_write_req_o           ( axi_tg_wide_out_r_write_req      ),
        .mst_write_resp_i          ( axi_tg_wide_out_r_write_rsp      )
    );

    read #(
        // AXI4 wide
        .C_M_AXI_WIDE_PORT_ID_WIDTH             (AXI_ID_WIDTH),
        .C_M_AXI_WIDE_PORT_ADDR_WIDTH           (AXI_ADDR_WIDTH),
        .C_M_AXI_WIDE_PORT_DATA_WIDTH           (AXI_DATA_WIDTH),
        .C_M_AXI_WIDE_PORT_AWUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_ARUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_WUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_RUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_BUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_USER_VALUE           (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_PROT_VALUE           (0),
        .C_M_AXI_WIDE_PORT_CACHE_VALUE          (3),
        //
        // .C_M_AXI_DATA_WIDTH                     (AXI_DATA_WIDTH),
        // .C_M_AXI_LOCK                           (AXI_LOCK),
        // AXI4-Lite control
        .C_S_AXI_CONTROL_DATA_WIDTH             (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_DATA_WIDTH                     (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_CONTROL_ADDR_WIDTH             (AXI_LITE_ADDR_WIDTH)
    ) i_axi_hls_tg_read (
        .ap_clk                     ( clk_i                                 ),
        .ap_rst_n                   ( rst_ni                                ),
        // AXI4 wide
        .m_axi_wide_port_AWVALID    ( axi_tg_wide_rw_out[0].aw_valid        ),
        .m_axi_wide_port_AWREADY    ( axi_tg_wide_rw_out[0].aw_ready        ),
        .m_axi_wide_port_AWADDR     ( axi_tg_wide_rw_out[0].aw_addr         ),
        .m_axi_wide_port_AWID       ( axi_tg_wide_rw_out[0].aw_id           ),
        .m_axi_wide_port_AWLEN      ( axi_tg_wide_rw_out[0].aw_len          ),
        .m_axi_wide_port_AWSIZE     ( axi_tg_wide_rw_out[0].aw_size         ),
        .m_axi_wide_port_AWBURST    ( axi_tg_wide_rw_out[0].aw_burst        ),
        .m_axi_wide_port_AWLOCK     ( axi_tg_wide_rw_out[0].aw_lock         ),
        .m_axi_wide_port_AWCACHE    ( axi_tg_wide_rw_out[0].aw_cache        ),
        .m_axi_wide_port_AWPROT     ( axi_tg_wide_rw_out[0].aw_prot         ),
        .m_axi_wide_port_AWQOS      ( axi_tg_wide_rw_out[0].aw_qos          ),
        .m_axi_wide_port_AWREGION   ( axi_tg_wide_rw_out[0].aw_region       ),
        .m_axi_wide_port_AWUSER     ( axi_tg_wide_rw_out[0].aw_user         ),
        .m_axi_wide_port_WVALID     ( axi_tg_wide_rw_out[0].w_valid         ),
        .m_axi_wide_port_WREADY     ( axi_tg_wide_rw_out[0].w_ready         ), 
        .m_axi_wide_port_WDATA      ( axi_tg_wide_rw_out[0].w_data          ),
        .m_axi_wide_port_WSTRB      ( axi_tg_wide_rw_out[0].w_strb          ),
        .m_axi_wide_port_WLAST      ( axi_tg_wide_rw_out[0].w_last          ),
        .m_axi_wide_port_WID        (                                       ), 
        .m_axi_wide_port_WUSER      ( axi_tg_wide_rw_out[0].w_user          ),
        .m_axi_wide_port_ARVALID    ( axi_tg_wide_rw_out[0].ar_valid        ),
        .m_axi_wide_port_ARREADY    ( axi_tg_wide_rw_out[0].ar_ready        ),
        .m_axi_wide_port_ARADDR     ( axi_tg_wide_rw_out[0].ar_addr         ),
        .m_axi_wide_port_ARID       ( axi_tg_wide_rw_out[0].ar_id           ),
        .m_axi_wide_port_ARLEN      ( axi_tg_wide_rw_out[0].ar_len          ),
        .m_axi_wide_port_ARSIZE     ( axi_tg_wide_rw_out[0].ar_size         ),
        .m_axi_wide_port_ARBURST    ( axi_tg_wide_rw_out[0].ar_burst        ),
        .m_axi_wide_port_ARLOCK     ( axi_tg_wide_rw_out[0].ar_lock         ),
        .m_axi_wide_port_ARCACHE    ( axi_tg_wide_rw_out[0].ar_cache        ),
        .m_axi_wide_port_ARPROT     ( axi_tg_wide_rw_out[0].ar_prot         ),
        .m_axi_wide_port_ARQOS      ( axi_tg_wide_rw_out[0].ar_qos          ),
        .m_axi_wide_port_ARREGION   ( axi_tg_wide_rw_out[0].ar_region       ),
        .m_axi_wide_port_ARUSER     ( axi_tg_wide_rw_out[0].ar_user         ),
        .m_axi_wide_port_RVALID     ( axi_tg_wide_rw_out[0].r_valid         ),
        .m_axi_wide_port_RREADY     ( axi_tg_wide_rw_out[0].r_ready         ),
        .m_axi_wide_port_RDATA      ( axi_tg_wide_rw_out[0].r_data          ),
        .m_axi_wide_port_RLAST      ( axi_tg_wide_rw_out[0].r_last          ),
        .m_axi_wide_port_RID        ( axi_tg_wide_rw_out[0].r_id            ),
        .m_axi_wide_port_RUSER      ( axi_tg_wide_rw_out[0].r_user          ),
        .m_axi_wide_port_RRESP      ( axi_tg_wide_rw_out[0].r_resp          ),
        .m_axi_wide_port_BVALID     ( axi_tg_wide_rw_out[0].b_valid         ),
        .m_axi_wide_port_BREADY     ( axi_tg_wide_rw_out[0].b_ready         ),
        .m_axi_wide_port_BRESP      ( axi_tg_wide_rw_out[0].b_resp          ),
        .m_axi_wide_port_BID        ( axi_tg_wide_rw_out[0].b_id            ),
        .m_axi_wide_port_BUSER      ( axi_tg_wide_rw_out[0].b_user          ),
        // AXI4-Lite control
        .s_axi_control_AWVALID      ( axi_lite_read_cfg.aw_valid            ),
        .s_axi_control_AWREADY      ( axi_lite_read_cfg.aw_ready            ),
        .s_axi_control_AWADDR       ( axi_lite_read_cfg.aw_addr             ),
        .s_axi_control_WVALID       ( axi_lite_read_cfg.w_valid             ),
        .s_axi_control_WREADY       ( axi_lite_read_cfg.w_ready             ),
        .s_axi_control_WDATA        ( axi_lite_read_cfg.w_data              ),
        .s_axi_control_WSTRB        ( axi_lite_read_cfg.w_strb              ),
        .s_axi_control_ARVALID      ( axi_lite_read_cfg.ar_valid            ),
        .s_axi_control_ARREADY      ( axi_lite_read_cfg.ar_ready            ),
        .s_axi_control_ARADDR       ( axi_lite_read_cfg.ar_addr             ),
        .s_axi_control_RVALID       ( axi_lite_read_cfg.r_valid             ),
        .s_axi_control_RREADY       ( axi_lite_read_cfg.r_ready             ),
        .s_axi_control_RDATA        ( axi_lite_read_cfg.r_data              ),
        .s_axi_control_RRESP        ( axi_lite_read_cfg.r_resp              ),
        .s_axi_control_BVALID       ( axi_lite_read_cfg.b_valid             ),
        .s_axi_control_BREADY       ( axi_lite_read_cfg.b_ready             ),
        .s_axi_control_BRESP        ( axi_lite_read_cfg.b_resp              ),
        // Interrupt
        .interrupt                  (                                       )
    );

    // AXI4 TG - Wide Write

    `AXI_ASSIGN_TO_REQ(axi_tg_wide_out_w_req, axi_tg_wide_rw_out[1])
    `AXI_ASSIGN_FROM_RESP(axi_tg_wide_rw_out[1], axi_tg_wide_out_w_rsp)

    axi_rw_split #(
        .axi_req_t  (floo_picobello_noc_pkg::axi_wide_out_req_t),
        .axi_resp_t (floo_picobello_noc_pkg::axi_wide_out_rsp_t)
    ) i_w_split (
        .clk_i,
        .rst_ni,
        // Read / Write Slave
        .slv_req_i                 ( axi_tg_wide_out_w_req      ),
        .slv_resp_o                ( axi_tg_wide_out_w_rsp      ),
        // Read Master
        .mst_read_req_o            ( axi_tg_wide_out_w_read_req     ),
        .mst_read_resp_i           ( axi_tg_wide_out_w_read_rsp     ),
        // Write Master
        .mst_write_req_o           ( axi_tg_wide_out_w_write_req      ),
        .mst_write_resp_i          ( axi_tg_wide_out_w_write_rsp      )
    );

    write #(
        // AXI4 wide
        .C_M_AXI_WIDE_PORT_ID_WIDTH             (AXI_ID_WIDTH),
        .C_M_AXI_WIDE_PORT_ADDR_WIDTH           (AXI_ADDR_WIDTH),
        .C_M_AXI_WIDE_PORT_DATA_WIDTH           (AXI_DATA_WIDTH),
        .C_M_AXI_WIDE_PORT_AWUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_ARUSER_WIDTH         (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_WUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_RUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_BUSER_WIDTH          (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_USER_VALUE           (AXI_USER_WIDTH),
        .C_M_AXI_WIDE_PORT_PROT_VALUE           (0),
        .C_M_AXI_WIDE_PORT_CACHE_VALUE          (3),
        //
        .C_M_AXI_DATA_WIDTH                     (AXI_DATA_WIDTH),
        // .C_M_AXI_LOCK                           (AXI_LOCK),
        // AXI4-Lite control
        .C_S_AXI_CONTROL_DATA_WIDTH             (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_DATA_WIDTH                     (AXI_LITE_DATA_WIDTH),
        .C_S_AXI_CONTROL_ADDR_WIDTH             (AXI_LITE_ADDR_WIDTH)
    ) i_axi_hls_tg_write (
        .ap_clk                     ( clk_i                             ),
        .ap_rst_n                   ( rst_ni                            ),
        // AXI4 wide
        .m_axi_wide_port_AWVALID    ( axi_tg_wide_rw_out[1].aw_valid        ),
        .m_axi_wide_port_AWREADY    ( axi_tg_wide_rw_out[1].aw_ready        ),
        .m_axi_wide_port_AWADDR     ( axi_tg_wide_rw_out[1].aw_addr         ),
        .m_axi_wide_port_AWID       ( axi_tg_wide_rw_out[1].aw_id           ),
        .m_axi_wide_port_AWLEN      ( axi_tg_wide_rw_out[1].aw_len          ),
        .m_axi_wide_port_AWSIZE     ( axi_tg_wide_rw_out[1].aw_size         ),
        .m_axi_wide_port_AWBURST    ( axi_tg_wide_rw_out[1].aw_burst        ),
        .m_axi_wide_port_AWLOCK     ( axi_tg_wide_rw_out[1].aw_lock         ),
        .m_axi_wide_port_AWCACHE    ( axi_tg_wide_rw_out[1].aw_cache        ),
        .m_axi_wide_port_AWPROT     ( axi_tg_wide_rw_out[1].aw_prot         ),
        .m_axi_wide_port_AWQOS      ( axi_tg_wide_rw_out[1].aw_qos          ),
        .m_axi_wide_port_AWREGION   ( axi_tg_wide_rw_out[1].aw_region       ),
        .m_axi_wide_port_AWUSER     ( axi_tg_wide_rw_out[1].aw_user         ),
        .m_axi_wide_port_WVALID     ( axi_tg_wide_rw_out[1].w_valid         ),
        .m_axi_wide_port_WREADY     ( axi_tg_wide_rw_out[1].w_ready         ), 
        .m_axi_wide_port_WDATA      ( axi_tg_wide_rw_out[1].w_data          ),
        .m_axi_wide_port_WSTRB      ( axi_tg_wide_rw_out[1].w_strb          ),
        .m_axi_wide_port_WLAST      ( axi_tg_wide_rw_out[1].w_last          ),
        .m_axi_wide_port_WID        (                                       ), 
        .m_axi_wide_port_WUSER      ( axi_tg_wide_rw_out[1].w_user          ),
        .m_axi_wide_port_ARVALID    ( axi_tg_wide_rw_out[1].ar_valid        ),
        .m_axi_wide_port_ARREADY    ( axi_tg_wide_rw_out[1].ar_ready        ),
        .m_axi_wide_port_ARADDR     ( axi_tg_wide_rw_out[1].ar_addr         ),
        .m_axi_wide_port_ARID       ( axi_tg_wide_rw_out[1].ar_id           ),
        .m_axi_wide_port_ARLEN      ( axi_tg_wide_rw_out[1].ar_len          ),
        .m_axi_wide_port_ARSIZE     ( axi_tg_wide_rw_out[1].ar_size         ),
        .m_axi_wide_port_ARBURST    ( axi_tg_wide_rw_out[1].ar_burst        ),
        .m_axi_wide_port_ARLOCK     ( axi_tg_wide_rw_out[1].ar_lock         ),
        .m_axi_wide_port_ARCACHE    ( axi_tg_wide_rw_out[1].ar_cache        ),
        .m_axi_wide_port_ARPROT     ( axi_tg_wide_rw_out[1].ar_prot         ),
        .m_axi_wide_port_ARQOS      ( axi_tg_wide_rw_out[1].ar_qos          ),
        .m_axi_wide_port_ARREGION   ( axi_tg_wide_rw_out[1].ar_region       ),
        .m_axi_wide_port_ARUSER     ( axi_tg_wide_rw_out[1].ar_user         ),
        .m_axi_wide_port_RVALID     ( axi_tg_wide_rw_out[1].r_valid         ),
        .m_axi_wide_port_RREADY     ( axi_tg_wide_rw_out[1].r_ready         ),
        .m_axi_wide_port_RDATA      ( axi_tg_wide_rw_out[1].r_data          ),
        .m_axi_wide_port_RLAST      ( axi_tg_wide_rw_out[1].r_last          ),
        .m_axi_wide_port_RID        ( axi_tg_wide_rw_out[1].r_id            ),
        .m_axi_wide_port_RUSER      ( axi_tg_wide_rw_out[1].r_user          ),
        .m_axi_wide_port_RRESP      ( axi_tg_wide_rw_out[1].r_resp          ),
        .m_axi_wide_port_BVALID     ( axi_tg_wide_rw_out[1].b_valid         ),
        .m_axi_wide_port_BREADY     ( axi_tg_wide_rw_out[1].b_ready         ),
        .m_axi_wide_port_BRESP      ( axi_tg_wide_rw_out[1].b_resp          ),
        .m_axi_wide_port_BID        ( axi_tg_wide_rw_out[1].b_id            ),
        .m_axi_wide_port_BUSER      ( axi_tg_wide_rw_out[1].b_user          ),
        // AXI4-Lite control
        .s_axi_control_AWVALID      ( axi_lite_write_cfg.aw_valid           ),
        .s_axi_control_AWREADY      ( axi_lite_write_cfg.aw_ready           ),
        .s_axi_control_AWADDR       ( axi_lite_write_cfg.aw_addr            ),
        .s_axi_control_WVALID       ( axi_lite_write_cfg.w_valid            ),
        .s_axi_control_WREADY       ( axi_lite_write_cfg.w_ready            ),
        .s_axi_control_WDATA        ( axi_lite_write_cfg.w_data             ),
        .s_axi_control_WSTRB        ( axi_lite_write_cfg.w_strb             ),
        .s_axi_control_ARVALID      ( axi_lite_write_cfg.ar_valid           ),
        .s_axi_control_ARREADY      ( axi_lite_write_cfg.ar_ready           ),
        .s_axi_control_ARADDR       ( axi_lite_write_cfg.ar_addr            ),
        .s_axi_control_RVALID       ( axi_lite_write_cfg.r_valid            ),
        .s_axi_control_RREADY       ( axi_lite_write_cfg.r_ready            ),
        .s_axi_control_RDATA        ( axi_lite_write_cfg.r_data             ),
        .s_axi_control_RRESP        ( axi_lite_write_cfg.r_resp             ),
        .s_axi_control_BVALID       ( axi_lite_write_cfg.b_valid            ),
        .s_axi_control_BREADY       ( axi_lite_write_cfg.b_ready            ),
        .s_axi_control_BRESP        ( axi_lite_write_cfg.b_resp             ),
        // Interrupt
        .interrupt                  (                                       )
    );

    assign axi_tg_wide_rw_out[0].aw_atop = axi_pkg::ATOP_NONE;
    assign axi_tg_wide_rw_out[1].aw_atop = axi_pkg::ATOP_NONE;

endmodule
