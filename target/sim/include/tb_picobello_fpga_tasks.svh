// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import fpga_picobello_pkg::*;

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
  // AW channel
  tb_axi_host_req_i.aw.id = '0;
  tb_axi_host_req_i.aw.addr = write_addr;
  tb_axi_host_req_i.aw.len = '0;
  tb_axi_host_req_i.aw.size = $clog2(AxiCfgHost.DataWidth/8);
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
  tb_axi_host_req_i.w.data = write_data;
  tb_axi_host_req_i.w.strb = write_strb;
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
  // AR channel
  tb_axi_host_req_i.ar.id = '0;
  tb_axi_host_req_i.ar.addr = read_addr;
  tb_axi_host_req_i.ar.len = '0;
  tb_axi_host_req_i.ar.size = $clog2(AxiCfgHost.DataWidth/8);
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
  read_data = tb_axi_host_rsp_o.r.data;
  read_rsp = tb_axi_host_rsp_o.r.resp;
  tb_axi_host_req_i.r_ready = 1'b0;
`ifdef VERBOSE
  $display ("[%0tns] picobello_read - Read 0x%h from address location 0x%h", $time, read_data, read_addr);
`endif
endtask

//////////////////
// Memory Tiles //
//////////////////

// Initialize memory tiles
task automatic picobello_init_mem_tiles();
  axi_host_addr_t int_mem_addr_start, int_mem_addr_end, int_mem_addr_offset;
  axi_host_data_t int_write_data;
  axi_host_rsp_t int_rsp;

  int_write_data = '0;
  int_mem_addr_offset = 16'h0001;

  mem_tile_select_loop: for (int i_mem = 0; i_mem < picobello_pkg::NumMemTiles; i_mem++) begin
    int_mem_addr_start = 32'hD000_0000 + i_mem * 32'h0010_0000;
    int_mem_addr_end = 32'hD000_0000 + i_mem * 32'h0010_0000 + 32'h000F_FFFF;
    mem_tile_init_loop: for (axi_host_addr_t i_addr = int_mem_addr_start; i_addr <= int_mem_addr_end; i_addr += int_mem_addr_offset) begin
      picobello_write(i_addr, int_write_data, 8'hf, int_rsp);
      assert(int_rsp == axi_pkg::RESP_OKAY);
    end
  end
endtask

/////////////////////////////
// Traffic generator Tiles //
/////////////////////////////

// Configure traffic generator
task automatic picobello_tg_cfg(
  input tg_cfg_t tg_cfg
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_write_data, int_read_data;
  axi_host_rsp_t int_rsp;

  // Set destination address of wide port
  int_addr = tg_cfg.traffic_gen_addr_base + 8'h10;
  int_write_data = tg_cfg.mem_addr_base;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Set traffic dimension
  int_addr = tg_cfg.traffic_gen_addr_base + 8'h1c;
  int_write_data = tg_cfg.TrafficGenTrafficDim;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Set compute dimension
  int_addr = tg_cfg.traffic_gen_addr_base + 8'h24;
  int_write_data = tg_cfg.TrafficGenComputeDim;
  picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // // Set traffic index
  // int_addr = tg_cfg.traffic_gen_addr_base + 8'h2c;
  // int_write_data = tg_cfg.TrafficGenIdx;
  // picobello_write(int_addr, int_write_data, 8'hf, int_rsp);
  // assert(int_rsp == axi_pkg::RESP_OKAY);
`ifdef VERBOSE
  $display ("[%0tns] picobello_tg_cfg - Configured TG-%d to access MEM-%d", $time, tg_cfg.traffic_gen_port_id, tg_cfg.mem_port_id);
`endif
endtask

// Run traffic generator
task automatic picobello_tg_start(
  input tg_cfg_t tg_cfg
);
  axi_host_data_t traffic_gen_start;
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data;
  axi_host_rsp_t int_rsp;

  // Read control register
  int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
  picobello_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);

  // Run traffic generator
  int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
  traffic_gen_start = (int_read_data & 32'h0000_0080) | 32'h0000_0001;
  picobello_write(int_addr, traffic_gen_start, 8'hf, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY);
endtask

// Wait for traffic generator to terminate execution
task automatic picobello_tg_polling(
  input tg_cfg_t tg_cfg
);
  axi_host_data_t traffic_gen_idle;
  axi_host_addr_t int_addr;
  axi_host_data_t int_read_data;
  axi_host_rsp_t int_rsp;

  // Check traffic generator idleness  
  traffic_gen_idle = '0;  
  while (~traffic_gen_idle[0]) begin
    // Read control register
    int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
    picobello_read(int_addr, int_read_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);
`ifdef VERBOSE
    $display ("[%0tns] picobello_tg_polling - Control register: 0x%h", $time, int_read_data);
`endif
    traffic_gen_idle = (int_read_data >> 2) & 32'h0000_0001; // - TO-DO: check why different wrt. accelerator driver
  end
endtask

// Validate traffic generator results
task automatic picobello_tg_validation(
  input tg_cfg_t tg_cfg,
  input axi_host_data_t golden_value
);
  axi_host_addr_t int_addr;
  axi_host_data_t int_golden_value;
  axi_host_data_t int_read_data;
  axi_host_rsp_t int_rsp;

  // Read memory value and assert correctness
  int_addr = tg_cfg.mem_addr_base;
  int_golden_value = golden_value;
  picobello_read(int_addr, int_read_data, int_rsp);
  assert(int_rsp == axi_pkg::RESP_OKAY); 
  assert(int_read_data == int_golden_value);
endtask