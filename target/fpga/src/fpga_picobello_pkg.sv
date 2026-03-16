// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

package fpga_picobello_pkg;
  import picobello_pkg::*; 
  import floo_pkg::*;
  import floo_picobello_noc_pkg::*;

  /////////
  // SoC //
  /////////

  // SoC parameters
  localparam int unsigned NumFpgaHostPorts = 1;
  localparam int unsigned NumFpgaDummyTiles = 2;

  //////////
  // Host //
  //////////

  // AXI4 wide configuration for host processor
  localparam axi_cfg_t AxiCfgHost = '{
    AddrWidth: floo_picobello_noc_pkg::AxiCfgN.AddrWidth,
    DataWidth: floo_picobello_noc_pkg::AxiCfgN.DataWidth,
    UserWidth: floo_picobello_noc_pkg::AxiCfgN.UserWidth, // before: 4
    InIdWidth: floo_picobello_noc_pkg::AxiCfgN.InIdWidth, // before: 3
    OutIdWidth: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth // before: 3
  };
  typedef logic [AxiCfgHost.AddrWidth-1:0] axi_host_addr_t;
  typedef logic [AxiCfgHost.DataWidth-1:0] axi_host_data_t;
  typedef logic [AxiCfgHost.DataWidth/8-1:0] axi_host_strb_t;
  typedef logic [AxiCfgHost.OutIdWidth-1:0] axi_host_id_t;
  typedef logic [AxiCfgHost.UserWidth-1:0] axi_host_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_host, axi_host_req_t, axi_host_rsp_t, axi_host_addr_t,
                      axi_host_id_t, axi_host_data_t, axi_host_strb_t,
                      axi_host_user_t)

  /////////////
  // RT Tile //
  /////////////

  // Number of cores per tile
  localparam int unsigned NumCores = 8; // cores per cluster tile

  // AXI4 wide configuration for RT traffic (Traffic generator => AXI-Realm => MUX)
  localparam axi_cfg_t AxiCfgWTrafficGen = '{
    AddrWidth: floo_picobello_noc_pkg::AxiCfgW.AddrWidth,
    DataWidth: floo_picobello_noc_pkg::AxiCfgW.DataWidth,
    UserWidth: floo_picobello_noc_pkg::AxiCfgW.UserWidth,
    InIdWidth: 5,
    OutIdWidth: 5
  };

  typedef logic [AxiCfgWTrafficGen.AddrWidth-1:0] axi_wide_tg_addr_t;
  typedef logic [AxiCfgWTrafficGen.DataWidth-1:0] axi_wide_tg_data_t;
  typedef logic [AxiCfgWTrafficGen.DataWidth/8-1:0] axi_wide_tg_strb_t;
  typedef logic [AxiCfgWTrafficGen.OutIdWidth-1:0] axi_wide_tg_id_t;
  typedef logic [AxiCfgWTrafficGen.UserWidth-1:0] axi_wide_tg_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_wide_tg, axi_wide_tg_req_t, axi_wide_tg_rsp_t,
                      axi_wide_tg_addr_t, axi_wide_tg_id_t, axi_wide_tg_data_t,
                      axi_wide_tg_strb_t, axi_wide_tg_user_t)

  // AXI4 configuration downsized data width (before AXI4-Lite conversion)
  localparam axi_cfg_t AxiCfgDataDownsized = '{
    AddrWidth: floo_picobello_noc_pkg::AxiCfgN.AddrWidth,
    DataWidth: 32,
    UserWidth: floo_picobello_noc_pkg::AxiCfgN.UserWidth,
    InIdWidth: floo_picobello_noc_pkg::AxiCfgN.InIdWidth,
    OutIdWidth: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth
  };

  typedef logic [AxiCfgDataDownsized.AddrWidth-1:0] axi_narrow_out_data_downsized_addr_t;
  typedef logic [AxiCfgDataDownsized.DataWidth-1:0] axi_narrow_out_data_downsized_data_t;
  typedef logic [AxiCfgDataDownsized.DataWidth/8-1:0] axi_narrow_out_data_downsized_strb_t;
  typedef logic [AxiCfgDataDownsized.OutIdWidth-1:0] axi_narrow_out_data_downsized_id_t;
  typedef logic [AxiCfgDataDownsized.UserWidth-1:0] axi_narrow_out_data_downsized_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_narrow_out_data_downsized, axi_narrow_out_data_downsized_req_t, axi_narrow_out_data_downsized_rsp_t,
                      axi_narrow_out_data_downsized_addr_t, axi_narrow_out_data_downsized_id_t, axi_narrow_out_data_downsized_data_t,
                      axi_narrow_out_data_downsized_strb_t, axi_narrow_out_data_downsized_user_t)

  // AXI4 configuration downsized address width (before AXI4-Lite conversion)
  localparam axi_cfg_t AxiCfgAddrDownsized = '{
    AddrWidth: 32,
    DataWidth: 32,
    UserWidth: floo_picobello_noc_pkg::AxiCfgN.UserWidth,
    InIdWidth: floo_picobello_noc_pkg::AxiCfgN.InIdWidth,
    OutIdWidth: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth
  };

  typedef logic [AxiCfgAddrDownsized.AddrWidth-1:0] axi_narrow_out_addr_downsized_addr_t;
  typedef logic [AxiCfgAddrDownsized.DataWidth-1:0] axi_narrow_out_addr_downsized_data_t;
  typedef logic [AxiCfgAddrDownsized.DataWidth/8-1:0] axi_narrow_out_addr_downsized_strb_t;
  typedef logic [AxiCfgAddrDownsized.OutIdWidth-1:0] axi_narrow_out_addr_downsized_id_t;
  typedef logic [AxiCfgAddrDownsized.UserWidth-1:0] axi_narrow_out_addr_downsized_user_t;
  `AXI_TYPEDEF_ALL_CT(axi_narrow_out_addr_downsized, axi_narrow_out_addr_downsized_req_t, axi_narrow_out_addr_downsized_rsp_t,
                      axi_narrow_out_addr_downsized_addr_t, axi_narrow_out_addr_downsized_id_t, axi_narrow_out_addr_downsized_data_t,
                      axi_narrow_out_addr_downsized_strb_t, axi_narrow_out_addr_downsized_user_t)

  // AXI4-Lite configuration
  localparam axi_cfg_t AxiLiteCfg = '{
    AddrWidth: 32,
    DataWidth: 32,
    UserWidth: floo_picobello_noc_pkg::AxiCfgN.UserWidth,
    InIdWidth: floo_picobello_noc_pkg::AxiCfgN.InIdWidth,
    OutIdWidth: floo_picobello_noc_pkg::AxiCfgN.OutIdWidth
  };
  typedef logic [AxiLiteCfg.AddrWidth-1:0] axi_lite_host_addr_t;
  typedef logic [AxiLiteCfg.DataWidth-1:0] axi_lite_host_data_t;
  typedef logic [AxiLiteCfg.DataWidth/8-1:0] axi_lite_host_strb_t;
  `AXI_LITE_TYPEDEF_ALL_CT(axi_lite_host, axi_lite_host_req_t, axi_lite_host_rsp_t, 
                           axi_lite_host_addr_t, axi_lite_host_data_t, axi_lite_host_strb_t)

  ///////////////
  // AXI-Realm //
  ///////////////

  // Number of masters
  localparam int unsigned NumManagers     = NumCores;
  // Number of slaves
  localparam int unsigned NumSubordinates = 32'd1;
  // Number of regions per master
  localparam int unsigned NumRegions      = 32'd1;
  // Max burst length
  localparam int unsigned MaxBurstLength  = 32'd128;
  // Number of outstanding transactions
  localparam int unsigned NumPending      = MaxBurstLength;
  // Write buffer depth
  localparam int unsigned WBufferDepth    = MaxBurstLength;
  // QoS parameters
  localparam int unsigned PeriodWidth     = 32'd32;
  localparam int unsigned BudgetWidth     = 32'd32;

  // RT ID
  localparam int unsigned AxiSlvIdWidth = (NumManagers == 32'd1 & NumSubordinates == 32'd1) ?
                                            AxiCfgW.OutIdWidth :
                                            AxiCfgW.OutIdWidth + cf_math_pkg::idx_width(NumManagers);

  typedef logic [AxiSlvIdWidth-1 :0] slv_id_t;

  `REG_BUS_TYPEDEF_ALL(cfg, axi_lite_host_addr_t, axi_lite_host_data_t, axi_lite_host_strb_t)

  // AXI-Realm configuration struct
  typedef struct packed {
    // Register file base address
    axi_host_addr_t rt_reg_addr_base;
    // Register file base address offset
    axi_host_addr_t rt_reg_addr_offset;
    // Manager ID
    int mgr_id;
    // Manager address space dimension
    axi_host_addr_t mgr_addr_space_dim;
    // Subordinate address region ID
    int sbr_addr_reg_id;
    // Configuration registers
    axi_rt_reg_pkg::axi_rt_reg2hw_t rt_regfile_cfg;
  } rt_cfg_t;

  ///////////////////////
  // Traffic Generator //
  ///////////////////////

  // TG parameters
  localparam bit UseHlsTg = 1'b0; // Use synthesizable traffic generator or DMA test node

  // Traffic generator configuration struct
  typedef struct packed {
    // Port IDs
    logic [3:0] traffic_gen_port_id;
    logic [3:0] mem_port_id;
    // Addresses and offsets
  	axi_host_addr_t traffic_gen_addr_base; // Traffic generator base address
    axi_host_addr_t traffic_gen_addr_offset; // Traffic generator address offset
    axi_host_addr_t mem_addr_base; // Memory base address
    axi_host_addr_t mem_addr_offset; // Memory address offset
    // Traffic generator parameters
    axi_host_data_t TrafficGenTrafficDim; // Traffic dimension
    axi_host_data_t TrafficGenComputeDim; // Compute dimension
    axi_host_data_t TrafficGenIdx; // Index
  } tg_cfg_t;

  // Timer counter (used during RTL simulation of the FPGA top)
  typedef struct packed {
    logic          write_counter_i; // [Input] Counter overwrite control
    logic [32-1:0] counter_value_i; // [Input] Counter value to set
    logic          reset_count_i; // [Input] Counter reset control
    logic          enable_count_i; // [Input] Counter enable control - to increase the counter value
    logic [32-1:0] compare_value_i; // [Input] Comparator value - to compare with the counter value
    // logic [32-1:0] counter_value_o; // [Output] Counter value
    // logic          target_reached_o; // [Output] Comparator value flag
  } timer_cfg_t;

endpackage
