// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import picobello_pkg::*;

`define wait_for(signal) do @(posedge `CLK_SIGNAL); while (!signal);

///////////
// Timer //
///////////

// Reset and initialize timer
task automatic picobello_reset_timer(
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
task automatic picobello_start_timer(
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
task automatic picobello_stop_timer(
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
task automatic picobello_write(
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
  $display ("[%0tns] picobello_write - Write 0x%h to address location 0x%h", $time, write_data, write_addr);
`endif
endtask

// Read from Picobello through the AXI4 host interface
task automatic picobello_read(
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
  $display ("[%0tns] picobello_read - Read 0x%h from address location 0x%h", $time, read_data, read_addr);
`endif
endtask
