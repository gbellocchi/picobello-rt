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
  localparam int unsigned NumTrafficGenerators = picobello_pkg::NumClusters + 1; // Snitch clusters and FhG SPU

  //////////
  // AXI4 //
  //////////
  
  // Host AXI4 parameters and typedefs
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

  ///////////////
  // AXI4-Lite //
  ///////////////

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
  // L2 Memory //
  ///////////////

  localparam int unsigned L2AddrWidth = floo_picobello_noc_pkg::AxiCfgW.AddrWidth;
  localparam int unsigned L2DataWidth = floo_picobello_noc_pkg::AxiCfgW.DataWidth;
  localparam int unsigned L2IdWidth   = floo_picobello_noc_pkg::AxiCfgW.OutIdWidth;
  localparam int unsigned L2UserWidth = floo_picobello_noc_pkg::AxiCfgW.UserWidth;

  ///////////////
  // AXI-Realm //
  ///////////////

  // Number of masters
  localparam int unsigned NumMasters      = 32'd1;
  // Number of slaves
  localparam int unsigned NumSlaves       = 32'd1;
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
  localparam int unsigned AxiSlvIdWidth = (NumMasters == 32'd1 & NumSlaves == 32'd1) ?
                                            AxiCfgW.OutIdWidth :
                                            AxiCfgW.OutIdWidth + cf_math_pkg::idx_width(NumMasters);

  typedef logic [AxiSlvIdWidth-1 :0] slv_id_t;

  `REG_BUS_TYPEDEF_ALL(cfg, axi_lite_host_addr_t, axi_lite_host_data_t, axi_lite_host_strb_t)

  // AXI-Realm configuration struct
  typedef struct packed {
    // Register file base address
    axi_host_addr_t rt_reg_addr_base;
    // Address region
    int addr_reg_id;
    // Address region
    int mrg_id;
    // Configuration registers
    axi_rt_reg_pkg::axi_rt_reg2hw_t rt_regfile_cfg;
  } rt_cfg_t;

  ///////////////////////
  // Traffic Generator //
  ///////////////////////

  // Traffic generator configuration struct
  typedef struct packed {
    // Port IDs
    logic [3:0] traffic_gen_port_id;
    logic [3:0] mem_port_id;
    // Addresses
  	axi_host_addr_t traffic_gen_addr_base; // Traffic generator base address
    axi_host_addr_t mem_addr_base; // Memory base address
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
