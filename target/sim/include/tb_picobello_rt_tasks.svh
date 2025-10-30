// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import fpga_picobello_pkg::*;
import sim_picobello_pkg::*;
import axi_rt_reg_pkg::* ;

////////////////
// BW monitor //
////////////////

// Reset and initialize BW monitor
task automatic picobello_reset_bw_monitor(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0],
  input int cl_idx,
  input int core_idx
);
  bw_monitor[cl_idx][core_idx].rst_r_cnt = 1'b1;
  bw_monitor[cl_idx][core_idx].rst_w_cnt = 1'b1;
  @(posedge `CLK_SIGNAL);
  bw_monitor[cl_idx][core_idx].rst_r_cnt = 1'b0;
  bw_monitor[cl_idx][core_idx].rst_w_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Start BW monitor on read channels
task automatic picobello_start_bw_r_monitor(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0],
  input int cl_idx,
  input int core_idx
);
  bw_monitor[cl_idx][core_idx].en_r_cnt = 1'b1;
  bw_monitor[cl_idx][core_idx].rst_r_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Start BW monitor on write channels
task automatic picobello_start_bw_w_monitor(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0],
  input int cl_idx,
  input int core_idx
);
  bw_monitor[cl_idx][core_idx].en_w_cnt = 1'b1;
  bw_monitor[cl_idx][core_idx].rst_w_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Stop BW monitor on read channels
task automatic picobello_stop_bw_r_monitor(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0],
  input int cl_idx,
  input int core_idx
);
  bw_monitor[cl_idx][core_idx].en_r_cnt = 1'b0;
  bw_monitor[cl_idx][core_idx].rst_r_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Stop BW monitor on write channels
task automatic picobello_stop_bw_w_monitor(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][fpga_picobello_pkg::NumCores-1:0],
  input int cl_idx,
  input int core_idx
);
  @(posedge `CLK_SIGNAL);
  bw_monitor[cl_idx][core_idx].en_w_cnt = 1'b0;
  bw_monitor[cl_idx][core_idx].rst_w_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

///////////////
// AXI-Realm //
///////////////

// Check input RT configuration correctness
task automatic picobello_rt_check_cfg(
  input rt_cfg_t tb_rt_cfg
);
  // Check that the address region ID is consistent
  assert (tb_rt_cfg.sbr_addr_reg_id < (NumReg - 1)) else
    $fatal(1, "Address region ID %0d is not supported! A maximum of %0d regions are supported.", tb_rt_cfg.sbr_addr_reg_id, axi_rt_reg_pkg::NumReg);

  // Check that the manager ID is consistent
  assert (tb_rt_cfg.mgr_id < (NumMrg - 1)) else
    $fatal(1, "RT manager ID %0d is not supported! A maximum of %0d RT managers are supported.", tb_rt_cfg.mgr_id, axi_rt_reg_pkg::NumMrg);
endtask

// Configure AXI-Realm guard register
task automatic picobello_rt_guard_init(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Special guard register
  localparam axi_host_addr_t rt_guard_addr_auth = ('1 << 2);
  int excl_w, excl_r, valid;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // Configure guard register and claim ID
  // Bit 0 = 1: enables write exclusion (excl_w)
  // Bit 1 = 1: enables read exclusion (excl_r)
  // Bit 2 = 1: sets the valid bit (valid)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + rt_guard_addr_auth[(axi_rt_reg_pkg::BlockAw+1)-1:0];

  excl_w = 0;
  excl_r = 0;
  valid  = 1;
  int_write_data = (excl_w << 0) | (excl_r << 1) | (valid << 2);
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY); 

  // Read guard register
  // Note: ID is not readable at present
  int_addr       = tb_rt_cfg.rt_reg_addr_base + rt_guard_addr_auth[(axi_rt_reg_pkg::BlockAw+1)-1:0];
  picobello_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY); 
`ifdef VERBOSE
  $display ("[%0tns] picobello_rt_guard_init - Guard ID: 0x%h", $time, int_read_data);
`endif
endtask

// Configure AXI-Realm address region
task automatic picobello_rt_set_addr_reg(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // Start address sub low (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_START_ADDR_SUB_LOW_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_START_ADDR_SUB_LOW_1_OFFSET - AXI_RT_START_ADDR_SUB_LOW_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.start_addr_sub_low[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
  
  // Start address sub high (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_START_ADDR_SUB_HIGH_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_START_ADDR_SUB_HIGH_1_OFFSET - AXI_RT_START_ADDR_SUB_HIGH_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.start_addr_sub_high[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // End address sub low (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_END_ADDR_SUB_LOW_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_END_ADDR_SUB_LOW_1_OFFSET - AXI_RT_END_ADDR_SUB_LOW_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.end_addr_sub_low[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // End address sub high (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_END_ADDR_SUB_HIGH_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_END_ADDR_SUB_HIGH_1_OFFSET - AXI_RT_END_ADDR_SUB_HIGH_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.end_addr_sub_high[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Configure AXI-Realm period-budget QoS service
task automatic picobello_rt_set_period_budget(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // Read budget (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_READ_BUDGET_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_READ_BUDGET_1_OFFSET - AXI_RT_READ_BUDGET_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.read_budget[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Write budget (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_WRITE_BUDGET_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_WRITE_BUDGET_1_OFFSET - AXI_RT_WRITE_BUDGET_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.write_budget[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Read period (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_READ_PERIOD_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_READ_PERIOD_1_OFFSET - AXI_RT_READ_PERIOD_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.read_period[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Write period (32b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_WRITE_PERIOD_0_OFFSET + tb_rt_cfg.sbr_addr_reg_id * (AXI_RT_WRITE_PERIOD_1_OFFSET - AXI_RT_WRITE_PERIOD_0_OFFSET);
  int_write_data = tb_rt_cfg.rt_regfile_cfg.write_period[0] & 32'hFFFF_FFFF;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Configure AXI-Realm burst splitter
task automatic picobello_rt_set_burst_length(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  int num_bytes_len_limit_reg = $bits(32)/8;
  int len_limit_reg_offset = tb_rt_cfg.mrg_id/num_bytes_len_limit_reg;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // Length limit (8b)
  // len_limit values are stored in groups of 4 within each 32-bit register. Therefore, a different 
  // register offset is used to calculate the destination address for each group of 4 len_limit entries.
  case (len_limit_reg_offset)
    0: int_addr = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_LEN_LIMIT_0_OFFSET;
    1: int_addr = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_LEN_LIMIT_1_OFFSET;
  endcase
  int_write_data = (tb_rt_cfg.rt_regfile_cfg.len_limit[tb_rt_cfg.mrg_id] & 8'hFF) 
                   << (8 * (tb_rt_cfg.mrg_id % num_bytes_len_limit_reg));
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Enable IMTU mode
task automatic picobello_rt_enable_imtu(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // IMTU enable (1b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_IMTU_ENABLE_OFFSET;
  int_write_data = (tb_rt_cfg.rt_regfile_cfg.imtu_enable[tb_rt_cfg.mgr_id] & 1'b1) 
                   << tb_rt_cfg.mgr_id;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Abort IMTU mode
task automatic picobello_rt_abort_imtu(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // IMTU abort (1b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_IMTU_ABORT_OFFSET;
  int_write_data = (tb_rt_cfg.rt_regfile_cfg.imtu_abort[tb_rt_cfg.mgr_id] & 1'b1) 
                   << tb_rt_cfg.mgr_id;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

endtask

// Enable RT mode
task automatic picobello_rt_enable_rt(
  input rt_cfg_t tb_rt_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check input RT configuration validity
  picobello_rt_check_cfg(tb_rt_cfg);

  // RT enable (1b)
  int_addr       = tb_rt_cfg.rt_reg_addr_base + axi_rt_reg_pkg::AXI_RT_RT_ENABLE_OFFSET;
  int_write_data = (tb_rt_cfg.rt_regfile_cfg.rt_enable[tb_rt_cfg.mrg_id] & 1'b1) 
                   << tb_rt_cfg.mrg_id;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask