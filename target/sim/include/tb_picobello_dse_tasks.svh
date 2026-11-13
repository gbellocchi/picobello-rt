// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import picobello_pkg::*;
import sim_picobello_pkg::*;
import axi_rt_reg_pkg::* ;

///////////
// Timer //
///////////

// Reset and initialize timer
task automatic dse_reset_timer(
  ref timer_cfg_t timer_cfg
);
  // Reset the timer first
  @(posedge `CLK_SIGNAL);
  timer_cfg.write_counter_i = 1'b0;
  timer_cfg.counter_value_i = 32'b0;
  timer_cfg.reset_count_i = 1'b1;
  timer_cfg.enable_count_i = 1'b0;
  timer_cfg.compare_value_i = 32'b0;
  
  // Release reset and initialize to known state
  @(posedge `CLK_SIGNAL);
  timer_cfg.write_counter_i = 1'b0;
  timer_cfg.counter_value_i = 32'b0;
  timer_cfg.reset_count_i = 1'b0;
  timer_cfg.enable_count_i = 1'b0;
  timer_cfg.compare_value_i = 32'b0;
endtask

// Start timer
task automatic dse_start_timer(
  ref timer_cfg_t timer_cfg
);
  @(posedge `CLK_SIGNAL);
  timer_cfg.write_counter_i = 1'b0;
  timer_cfg.counter_value_i = 32'b0;
  timer_cfg.reset_count_i = 1'b0;
  timer_cfg.enable_count_i = 1'b1;
  timer_cfg.compare_value_i = 32'b0;
endtask

// Stop timer
task automatic dse_stop_timer(
  ref timer_cfg_t timer_cfg
);
  @(posedge `CLK_SIGNAL);
  timer_cfg.write_counter_i = 1'b0;
  timer_cfg.counter_value_i = 32'b0;
  timer_cfg.reset_count_i = 1'b0;
  timer_cfg.enable_count_i = 1'b0;
  timer_cfg.compare_value_i = 32'b0;
endtask

/////////////////////
// AXI4 Read/Write //
/////////////////////

// Write to Picobello through the AXI4 host interface
task automatic dse_write(
  input axi_host_addr_t write_addr, 
  input axi_host_data_t write_data, 
  input axi_host_strb_t write_strb,
  output axi_host_rsp_t write_rsp
);
  // 32-bit access on the 64-bit host port: the address selects the byte lanes
  int unsigned lane;
  lane = (write_addr[2]) ? 4 : 0;
  // AW channel
  tb_axi_host_req_i.aw.id = '0;
  tb_axi_host_req_i.aw.addr = write_addr;
  tb_axi_host_req_i.aw.len = '0;
  tb_axi_host_req_i.aw.size = 3'd2;
  tb_axi_host_req_i.aw.burst = axi_pkg::BURST_INCR;
  tb_axi_host_req_i.aw.lock = 1'b0;
  tb_axi_host_req_i.aw.cache = '0;
  tb_axi_host_req_i.aw.prot = '0;
  tb_axi_host_req_i.aw.qos = '0;
  tb_axi_host_req_i.aw.region = '0;
  tb_axi_host_req_i.aw.atop = axi_pkg::ATOP_NONE;
  tb_axi_host_req_i.aw.user = '0;
  tb_axi_host_req_i.aw_valid = 1'b1;
  `wait_for(tb_axi_host_rsp_o.aw_ready)
  tb_axi_host_req_i.aw_valid = 1'b0;
  // W channel
  tb_axi_host_req_i.w.data = write_data << (8 * lane);
  tb_axi_host_req_i.w.strb = write_strb << lane;
  tb_axi_host_req_i.w.last = 1'b1;
  tb_axi_host_req_i.w.user = '0;
  tb_axi_host_req_i.w_valid = 1'b1;
  `wait_for(tb_axi_host_rsp_o.w_ready)
  tb_axi_host_req_i.w_valid = 1'b0;
  // B channel
  tb_axi_host_req_i.b_ready = 1'b1;
  `wait_for(tb_axi_host_rsp_o.b_valid)
  write_rsp = tb_axi_host_rsp_o.b.resp;
  tb_axi_host_req_i.b_ready = 1'b0;
`ifdef VERBOSE
  $display ("[%0tns] dse_write - Write 0x%h to address location 0x%h", $time, write_data, write_addr);
`endif
endtask

// Read from Picobello through the AXI4 host interface
task automatic dse_read(
  input axi_host_addr_t read_addr, 
  output axi_host_data_t read_data, 
  output axi_host_rsp_t read_rsp
);
  // 32-bit access on the 64-bit host port: the address selects the byte lanes
  int unsigned lane;
  lane = (read_addr[2]) ? 4 : 0;
  // AR channel
  tb_axi_host_req_i.ar.id = '0;
  tb_axi_host_req_i.ar.addr = read_addr;
  tb_axi_host_req_i.ar.len = '0;
  tb_axi_host_req_i.ar.size = 3'd2;
  tb_axi_host_req_i.ar.burst = axi_pkg::BURST_INCR;
  tb_axi_host_req_i.ar.lock = 1'b0;
  tb_axi_host_req_i.ar.cache = '0;
  tb_axi_host_req_i.ar.prot = '0;
  tb_axi_host_req_i.ar.qos = '0;
  tb_axi_host_req_i.ar.region = '0;
  tb_axi_host_req_i.ar.user = '0;
  tb_axi_host_req_i.ar_valid = 1'b1;
  `wait_for(tb_axi_host_rsp_o.ar_ready)
  tb_axi_host_req_i.ar_valid = 1'b0;
  // R channel
  tb_axi_host_req_i.r_ready = 1'b1;
  `wait_for(tb_axi_host_rsp_o.r_valid)
  read_data = (tb_axi_host_rsp_o.r.data >> (8 * lane)) & 32'hFFFF_FFFF;
  read_rsp = tb_axi_host_rsp_o.r.resp;
  tb_axi_host_req_i.r_ready = 1'b0;
`ifdef VERBOSE
  $display ("[%0tns] dse_read - Read 0x%h from address location 0x%h", $time, read_data, read_addr);
`endif
endtask

/////////////////////
// BW monitor (1D) //
/////////////////////

// Reset and initialize BW monitor
task automatic dse_reset_bw_monitor_1d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0],
  input int cl_idx
);
  bw_monitor[cl_idx].rst_r_cnt = 1'b1;
  bw_monitor[cl_idx].rst_w_cnt = 1'b1;
  @(posedge `CLK_SIGNAL);
  bw_monitor[cl_idx].rst_r_cnt = 1'b0;
  bw_monitor[cl_idx].rst_w_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Start BW monitor on read channels
task automatic dse_start_bw_r_monitor_1d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0],
  input int cl_idx
);
  bw_monitor[cl_idx].en_r_cnt = 1'b1;
  bw_monitor[cl_idx].rst_r_cnt = 1'b0;
endtask

// Start BW monitor on write channels
task automatic dse_start_bw_w_monitor_1d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0],
  input int cl_idx
);
  bw_monitor[cl_idx].en_w_cnt = 1'b1;
  bw_monitor[cl_idx].rst_w_cnt = 1'b0;
endtask

// Stop BW monitor on read channels
task automatic dse_stop_bw_r_monitor_1d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0],
  input int cl_idx
);
  bw_monitor[cl_idx].en_r_cnt = 1'b0;
  bw_monitor[cl_idx].rst_r_cnt = 1'b0;
endtask

// Stop BW monitor on write channels
task automatic dse_stop_bw_w_monitor_1d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0],
  input int cl_idx
);
  bw_monitor[cl_idx].en_w_cnt = 1'b0;
  bw_monitor[cl_idx].rst_w_cnt = 1'b0;
endtask

/////////////////////
// BW monitor (2D) //
/////////////////////

// Reset and initialize BW monitor
task automatic dse_reset_bw_monitor_2d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][picobello_pkg::NumTrafficGen-1:0],
  input int cl_idx,
  input int traffic_gen_idx
);
  bw_monitor[cl_idx][traffic_gen_idx].rst_r_cnt = 1'b1;
  bw_monitor[cl_idx][traffic_gen_idx].rst_w_cnt = 1'b1;
  @(posedge `CLK_SIGNAL);
  bw_monitor[cl_idx][traffic_gen_idx].rst_r_cnt = 1'b0;
  bw_monitor[cl_idx][traffic_gen_idx].rst_w_cnt = 1'b0;
  @(posedge `CLK_SIGNAL);
endtask

// Start BW monitor on read channels
task automatic dse_start_bw_r_monitor_2d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][picobello_pkg::NumTrafficGen-1:0],
  input int cl_idx,
  input int traffic_gen_idx
);
  bw_monitor[cl_idx][traffic_gen_idx].en_r_cnt = 1'b1;
  bw_monitor[cl_idx][traffic_gen_idx].rst_r_cnt = 1'b0;
endtask

// Start BW monitor on write channels
task automatic dse_start_bw_w_monitor_2d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][picobello_pkg::NumTrafficGen-1:0],
  input int cl_idx,
  input int traffic_gen_idx
);
  bw_monitor[cl_idx][traffic_gen_idx].en_w_cnt = 1'b1;
  bw_monitor[cl_idx][traffic_gen_idx].rst_w_cnt = 1'b0;
endtask

// Stop BW monitor on read channels
task automatic dse_stop_bw_r_monitor_2d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][picobello_pkg::NumTrafficGen-1:0],
  input int cl_idx,
  input int traffic_gen_idx
);
  bw_monitor[cl_idx][traffic_gen_idx].en_r_cnt = 1'b0;
  bw_monitor[cl_idx][traffic_gen_idx].rst_r_cnt = 1'b0;
endtask

// Stop BW monitor on write channels
task automatic dse_stop_bw_w_monitor_2d(
  ref sim_picobello_pkg::bw_monitor_cfg_t bw_monitor [picobello_pkg::NumClusters-1:0][picobello_pkg::NumTrafficGen-1:0],
  input int cl_idx,
  input int traffic_gen_idx
);
  bw_monitor[cl_idx][traffic_gen_idx].en_w_cnt = 1'b0;
  bw_monitor[cl_idx][traffic_gen_idx].rst_w_cnt = 1'b0;
endtask

//////////////////////////////////////
// Injection regulation (AXI-REALM) //
//////////////////////////////////////

// Check that the AXI-REALM configuration is valid
task automatic dse_realm_check_cfg(
  input realm_cfg_t tb_realm_cfg
);
  // Check that the address region ID is consistent
  assert (tb_realm_cfg.sbr_addr_reg_id < NumReg) else
    $fatal(1, "Address region ID %0d is not supported! A maximum of %0d regions are supported.", tb_realm_cfg.sbr_addr_reg_id, axi_rt_reg_pkg::NumReg);

  // Check that the manager ID is consistent
  assert (tb_realm_cfg.mgr_id < NumMrg) else
    $fatal(1, "RT manager ID %0d is not supported! A maximum of %0d RT managers are supported.", tb_realm_cfg.mgr_id, axi_rt_reg_pkg::NumMrg);
endtask

// Configure AXI-Realm guard register
task automatic dse_realm_guard_init(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Special guard register
  localparam axi_host_addr_t guard_addr_auth = ('1 << 2);
  int excl_w, excl_r, valid;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // Configure guard register and claim ID
  // Bit 0 = 1: enables write exclusion (excl_w)
  // Bit 1 = 1: enables read exclusion (excl_r)
  // Bit 2 = 1: sets the valid bit (valid)
  int_addr       = tb_realm_cfg.regfile_addr_base + guard_addr_auth[(axi_rt_reg_pkg::BlockAw+1)-1:0];

  excl_w = 0;
  excl_r = 0;
  valid  = 1;
  int_write_data = (excl_w << 0) | (excl_r << 1) | (valid << 2);
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY); 

  // Read guard register
  // Note: ID is not readable at present
  int_addr       = tb_realm_cfg.regfile_addr_base + guard_addr_auth[(axi_rt_reg_pkg::BlockAw+1)-1:0];
  dse_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY); 
`ifdef VERBOSE
  $display ("[%0tns] dse_realm_guard_init - Guard ID: 0x%h", $time, int_read_data);
`endif
endtask

// Configure AXI-Realm address region
task automatic dse_realm_set_addr_reg(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // Start address sub low (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_START_ADDR_SUB_LOW_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_START_ADDR_SUB_LOW_1_OFFSET - AXI_RT_START_ADDR_SUB_LOW_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.start_addr_sub_low[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Start address sub high (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_START_ADDR_SUB_HIGH_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_START_ADDR_SUB_HIGH_1_OFFSET - AXI_RT_START_ADDR_SUB_HIGH_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.start_addr_sub_high[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // End address sub low (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_END_ADDR_SUB_LOW_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_END_ADDR_SUB_LOW_1_OFFSET - AXI_RT_END_ADDR_SUB_LOW_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.end_addr_sub_low[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // End address sub high (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_END_ADDR_SUB_HIGH_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_END_ADDR_SUB_HIGH_1_OFFSET - AXI_RT_END_ADDR_SUB_HIGH_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.end_addr_sub_high[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Configure AXI-Realm period-budget QoS service
task automatic dse_realm_set_period_budget(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // Read budget (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_READ_BUDGET_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_READ_BUDGET_1_OFFSET - AXI_RT_READ_BUDGET_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.read_budget[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Write budget (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_WRITE_BUDGET_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_WRITE_BUDGET_1_OFFSET - AXI_RT_WRITE_BUDGET_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.write_budget[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Read period (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_READ_PERIOD_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_READ_PERIOD_1_OFFSET - AXI_RT_READ_PERIOD_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.read_period[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Write period (32b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_WRITE_PERIOD_0_OFFSET + (tb_realm_cfg.mgr_id * axi_rt_reg_pkg::NumSub + tb_realm_cfg.sbr_addr_reg_id) * (AXI_RT_WRITE_PERIOD_1_OFFSET - AXI_RT_WRITE_PERIOD_0_OFFSET);
  int_write_data = tb_realm_cfg.regfile_cfg.write_period[tb_realm_cfg.sbr_addr_reg_id] & 32'hFFFF_FFFF;
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Configure AXI-Realm burst splitter
task automatic dse_realm_set_burst_length(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Each 32-bit len_limit register contains 4 entries of 8-bits to set len_limit values.
  // Each entry corresponds to a len_limit value for a different manager.
  // A len_limit value requires 8 bits to be represented, given AXI4 bursts can be up to 256 beats long.
  //
  // The following scheme refers to a configuration with 16 managers:
  //
  //  AXI_RT_LEN_LIMIT_0 (32-bit)                    
  //  ┌───────────┬───────────┬───────────┬───────────┐
  //  │  Mgr 3    │  Mgr 2    │  Mgr 1    │  Mgr 0    │
  //  │  [31:24]  │  [23:16]  │  [15:8]   │  [7:0]    │
  //  └───────────┴───────────┴───────────┴───────────┘
                                                    
  //  AXI_RT_LEN_LIMIT_1 (32-bit)                     
  //  ┌───────────┬───────────┬───────────┬───────────┐
  //  │  Mgr 7    │  Mgr 6    │  Mgr 5    │  Mgr 4    │
  //  │  [31:24]  │  [23:16]  │  [15:8]   │  [7:0]    │
  //  └───────────┴───────────┴───────────┴───────────┘
                                                    
  //  AXI_RT_LEN_LIMIT_2 (32-bit)                      
  //  ┌───────────┬───────────┬───────────┬───────────┐
  //  │  Mgr 11   │  Mgr 10   │  Mgr 9    │  Mgr 8    │
  //  │  [31:24]  │  [23:16]  │  [15:8]   │  [7:0]    │
  //  └───────────┴───────────┴───────────┴───────────┘
                                                    
  //  AXI_RT_LEN_LIMIT_3 (32-bit)                      
  //  ┌───────────┬───────────┬───────────┬───────────┐
  //  │  Mgr 15   │  Mgr 14   │  Mgr 13   │  Mgr 12   │
  //  │  [31:24]  │  [23:16]  │  [15:8]   │  [7:0]    │
  //  └───────────┴───────────┴───────────┴───────────┘

  // A 32-bit register stores 4 len_limit entries each.
  int num_bytes_len_limit_reg = 4;

  // Byte stride between consecutive 32-bit len_limit registers.
  int len_limit_reg_byte_stride = 4;

  // Calculate manager entry in the len_limit register.
  int len_limit_reg_entry_bytes = tb_realm_cfg.mgr_id % num_bytes_len_limit_reg;
  int len_limit_reg_entry_bits = 8 * len_limit_reg_entry_bytes;

  // Calculate the len_limit register offset based on the manager ID.
  int len_limit_reg_offset = tb_realm_cfg.mgr_id/num_bytes_len_limit_reg;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // Define AXI_RT_SINGLE_MANAGER when the generated AXI-REALM has a single manager, or undefine it when a multi-manager tile instance is used.
  `define AXI_RT_SINGLE_MANAGER
  
  // Address the target len_limit register starting from the base register address. len_limit values 
  // are stored in groups of 4 AXI4 managers within consecutive 32-bit registers. Each manager len_limit 
  // is allocated 8-bit since the max len_limit value is 256 Beats. 
`ifdef AXI_RT_SINGLE_MANAGER
  // Single manager: one len_limit register, un-suffixed; mgr_id is always 0.
  int_addr = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_LEN_LIMIT_OFFSET;
`else
  // Multi-manager: index off LEN_LIMIT_0 by 4 bytes per 32-bit register.
  int_addr = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_LEN_LIMIT_0_OFFSET +
             len_limit_reg_offset * len_limit_reg_byte_stride;
`endif

  // Read old len_limit register value to preserve other manager entries
  dse_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Preserve past entries and clear the 8-bit field to overwrite using a mask.
  // Then, overwrite the len_limit subfield with a new value and write back.
  int_write_data = (int_read_data & ~(32'hFF << len_limit_reg_entry_bits)) | 
                   ((tb_realm_cfg.regfile_cfg.len_limit[tb_realm_cfg.mgr_id] & 32'hFF) << len_limit_reg_entry_bits);
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Enable IMTU mode
task automatic dse_realm_enable_imtu(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // IMTU enable (1b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_IMTU_ENABLE_OFFSET;
  dse_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
  int_write_data = (int_read_data & ~(1'b1 << tb_realm_cfg.mgr_id)) |
                   ((tb_realm_cfg.regfile_cfg.imtu_enable[tb_realm_cfg.mgr_id] & 1'b1) << tb_realm_cfg.mgr_id);
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Abort IMTU mode
task automatic dse_realm_abort_imtu(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // IMTU abort (1b)
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_IMTU_ABORT_OFFSET;
  dse_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
  int_write_data = (int_read_data & ~(1'b1 << tb_realm_cfg.mgr_id)) |
                   ((tb_realm_cfg.regfile_cfg.imtu_abort[tb_realm_cfg.mgr_id] & 1'b1) << tb_realm_cfg.mgr_id);
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

endtask

// Enable AXI-REALM regulation (rt_enable)
task automatic dse_realm_enable_rt(
  input realm_cfg_t tb_realm_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data, int_write_data;
  axi_host_rsp_t int_rsp;

  // Check that the AXI-REALM configuration is valid
  dse_realm_check_cfg(tb_realm_cfg);

  // rt_enable register address
  int_addr       = tb_realm_cfg.regfile_addr_base + axi_rt_reg_pkg::AXI_RT_RT_ENABLE_OFFSET;

  // Read old enable register value to preserve other manager entries
  dse_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Preserve past entries and clear the 8-bit field to overwrite using a mask.
  // Then, overwrite the enable subfield with a new value and write back.
  int_write_data = (int_read_data & ~(1'b1 << tb_realm_cfg.mgr_id)) | 
                   ((tb_realm_cfg.regfile_cfg.rt_enable[tb_realm_cfg.mgr_id] & 1'b1) << tb_realm_cfg.mgr_id);
  dse_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask