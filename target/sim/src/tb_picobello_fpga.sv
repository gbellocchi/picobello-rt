// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`define wait_for(signal) do @(posedge clk); while (!signal);

// `define VERBOSE

module tb_picobello_fpga;

  import fpga_picobello_pkg::*;

  // TB parameters
  localparam time ClkPeriod = 10ns;

  // Host signals
  fpga_picobello_pkg::axi_host_req_t tb_axi_host_req_i;
  fpga_picobello_pkg::axi_host_rsp_t tb_axi_host_rsp_o;

  // Traffic generator configuration
  fpga_picobello_pkg::tg_cfg_t tb_tg_cfg;

  // General
  logic clk;
  logic rst_n;

  // Timer counter
  typedef struct packed {
    logic          write_counter_i; // [Input] Counter overwrite control
    logic [32-1:0] counter_value_i; // [Input] Counter value to set
    logic          reset_count_i; // [Input] Counter reset control
    logic          enable_count_i; // [Input] Counter enable control - to increase the counter value
    logic [32-1:0] compare_value_i; // [Input] Comparator value - to compare with the counter value
    // logic [32-1:0] counter_value_o; // [Output] Counter value
    // logic          target_reached_o; // [Output] Comparator value flag
  } timer_cfg_t;

  logic [32-1:0] counter_value_o; // [Output] Counter value
  logic          target_reached_o; // [Output] Comparator value flag

  timer_cfg_t tb_timer_cfg;

  // DUT
  fpga_picobello_top #(
    // Parameters
    .NumFpgaHostPorts         (fpga_picobello_pkg::NumFpgaHostPorts),  
    .NumFpgaDummyTiles        (fpga_picobello_pkg::NumFpgaDummyTiles),    
    .NumTrafficGenerators     (fpga_picobello_pkg::NumTrafficGenerators),
    // AXI4 channel types
    .axi_host_req_t           (fpga_picobello_pkg::axi_host_req_t),
    .axi_host_rsp_t           (fpga_picobello_pkg::axi_host_rsp_t),
    .axi_host_aw_chan_t       (fpga_picobello_pkg::axi_host_aw_chan_t),
    .axi_host_w_chan_t        (fpga_picobello_pkg::axi_host_w_chan_t),
    .axi_host_b_chan_t        (fpga_picobello_pkg::axi_host_b_chan_t),
    .axi_host_ar_chan_t       (fpga_picobello_pkg::axi_host_ar_chan_t),
    .axi_host_r_chan_t        (fpga_picobello_pkg::axi_host_r_chan_t),
    // AXI4-Lite channel types
    .axi_lite_host_req_t      (fpga_picobello_pkg::axi_lite_host_req_t),
    .axi_lite_host_rsp_t      (fpga_picobello_pkg::axi_lite_host_rsp_t),
    .axi_lite_host_aw_chan_t  (fpga_picobello_pkg::axi_lite_host_aw_chan_t),
    .axi_lite_host_w_chan_t   (fpga_picobello_pkg::axi_lite_host_w_chan_t),
    .axi_lite_host_b_chan_t   (fpga_picobello_pkg::axi_lite_host_b_chan_t),
    .axi_lite_host_ar_chan_t  (fpga_picobello_pkg::axi_lite_host_ar_chan_t),
    .axi_lite_host_r_chan_t   (fpga_picobello_pkg::axi_lite_host_r_chan_t)
  ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),
    .test_mode_i          (1'b0),
    .ext_axi_host_req_i   (tb_axi_host_req_i),
    .ext_axi_host_rsp_o   (tb_axi_host_rsp_o)
  );

  clk_rst_gen #(
    .ClkPeriod        (ClkPeriod),
    .RstClkCycles     (5)
  ) i_clk_gen (
    .clk_o            (clk),
    .rst_no           (rst_n)
  );

  timer_unit_counter counter_i (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .write_counter_i  (tb_timer_cfg.write_counter_i),
    .counter_value_i  (tb_timer_cfg.counter_value_i),
    .reset_count_i    (tb_timer_cfg.reset_count_i),
    .enable_count_i   (tb_timer_cfg.enable_count_i),
    .compare_value_i  (tb_timer_cfg.compare_value_i),
    .counter_value_o  (counter_value_o),
    .target_reached_o (target_reached_o)
  );

  // Initialize timer
  task automatic picobello_init_timer(
    output timer_cfg_t timer_cfg
  );
    timer_cfg.reset_count_i = 1'b1;
    @(posedge clk);
    timer_cfg.reset_count_i = 1'b0;
  endtask

  // Start timer
  task automatic picobello_start_timer(
    output timer_cfg_t timer_cfg
  );
    timer_cfg.write_counter_i = 1'b0;
    timer_cfg.counter_value_i = 32'b0;
    timer_cfg.reset_count_i = 1'b0;
    timer_cfg.enable_count_i = 1'b1;
    timer_cfg.compare_value_i = 32'b0;
  endtask

  // Stop timer
  task automatic picobello_stop_timer(
    output timer_cfg_t timer_cfg
  );
    timer_cfg.write_counter_i = 1'b0;
    timer_cfg.counter_value_i = 32'b0;
    timer_cfg.reset_count_i = 1'b0;
    timer_cfg.enable_count_i = 1'b0;
    timer_cfg.compare_value_i = 32'b0;
  endtask

  // Write to Picobello through the AXI4 host interface
  task automatic picobello_write(
    input fpga_picobello_pkg::axi_host_addr_t write_addr, 
    input fpga_picobello_pkg::axi_host_data_t write_data, 
    output fpga_picobello_pkg::axi_host_rsp_t write_rsp
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
    tb_axi_host_req_i.w.strb = '1;
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
    input fpga_picobello_pkg::axi_host_addr_t read_addr, 
    output fpga_picobello_pkg::axi_host_data_t read_data, 
    output fpga_picobello_pkg::axi_host_rsp_t read_rsp
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

  // Initialize memory tiles
  task picobello_init_mem_tiles();
    fpga_picobello_pkg::axi_host_addr_t int_mem_addr_start, int_mem_addr_end, int_mem_addr_offset;
    fpga_picobello_pkg::axi_host_data_t int_write_data;
    fpga_picobello_pkg::axi_host_rsp_t int_rsp;

    assign int_write_data = '0;
    assign int_mem_addr_offset = 16'h0001;

    mem_tile_select_loop: for (int i_mem = 0; i_mem < picobello_pkg::NumMemTiles; i_mem++) begin
      int_mem_addr_start = 32'hD000_0000 + i_mem * 32'h0010_0000;
      int_mem_addr_end = 32'hD000_0000 + i_mem * 32'h0010_0000 + 32'h000F_FFFF;
      mem_tile_init_loop: for (fpga_picobello_pkg::axi_host_addr_t i_addr = int_mem_addr_start; i_addr <= int_mem_addr_end; i_addr += int_mem_addr_offset) begin
        picobello_write(i_addr, int_write_data, int_rsp);
        assert(int_rsp == axi_pkg::RESP_OKAY);
      end
    end
  endtask

  // Configure traffic generator
  task picobello_tg_cfg(
    input fpga_picobello_pkg::tg_cfg_t tg_cfg
  );
    fpga_picobello_pkg::axi_host_addr_t int_addr;
    fpga_picobello_pkg::axi_host_data_t int_write_data, int_read_data;
    fpga_picobello_pkg::axi_host_rsp_t int_rsp;

    // Set destination address of narrow port
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h10;
    assign int_write_data = tg_cfg.mem_addr_base;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set destination address of wide port
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h1c;
    assign int_write_data = tg_cfg.mem_addr_base;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set traffic dimension
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h28;
    assign int_write_data = tg_cfg.TrafficGenTrafficDim;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set compute dimension
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h34;
    assign int_write_data = tg_cfg.TrafficGenComputeDim;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Set traffic index
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h40;
    assign int_write_data = tg_cfg.TrafficGenIdx;
    picobello_write(int_addr, int_write_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);
  `ifdef VERBOSE
    $display ("[%0tns] picobello_tg_cfg - Configured TG-%d to access MEM-%d", $time, tg_cfg.traffic_gen_port_id, tg_cfg.mem_port_id);
  `endif
  endtask

  // Run traffic generator
  task picobello_tg_start(
    input fpga_picobello_pkg::tg_cfg_t tg_cfg
  );
    fpga_picobello_pkg::axi_host_data_t traffic_gen_start;
    fpga_picobello_pkg::axi_host_addr_t int_addr;
    fpga_picobello_pkg::axi_host_data_t int_read_data;
    fpga_picobello_pkg::axi_host_rsp_t int_rsp;

    // Read control register
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
    picobello_read(int_addr, int_read_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);

    // Run traffic generator
    assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
    assign traffic_gen_start = (int_read_data & 32'h0000_0080) | 32'h0000_0001;
    picobello_write(int_addr, traffic_gen_start, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY);
  endtask

  // Wait for traffic generator to terminate execution
  task picobello_tg_polling(
    input fpga_picobello_pkg::tg_cfg_t tg_cfg
  );
    fpga_picobello_pkg::axi_host_data_t traffic_gen_idle;
    fpga_picobello_pkg::axi_host_addr_t int_addr;
    fpga_picobello_pkg::axi_host_data_t int_read_data;
    fpga_picobello_pkg::axi_host_rsp_t int_rsp;

    // Check traffic generator idleness  
    assign traffic_gen_idle = '0;  
    while (~traffic_gen_idle[0]) begin
      // Read control register
      assign int_addr = tg_cfg.traffic_gen_addr_base + 8'h00;
      picobello_read(int_addr, int_read_data, int_rsp);
      assert(int_rsp == axi_pkg::RESP_OKAY);
  `ifdef VERBOSE
      $display ("[%0tns] picobello_tg_polling - Control register: 0x%h", $time, int_read_data);
  `endif
      assign traffic_gen_idle = (int_read_data >> 2) & 32'h0000_0001; // - TO-DO: check why different wrt. accelerator driver
    end
  endtask

  // Validate traffic generator results
  task picobello_tg_validation(
    input fpga_picobello_pkg::tg_cfg_t tg_cfg,
    input fpga_picobello_pkg::axi_host_data_t golden_value
  );
    fpga_picobello_pkg::axi_host_addr_t int_addr;
    fpga_picobello_pkg::axi_host_data_t int_golden_value;
    fpga_picobello_pkg::axi_host_data_t int_read_data;
    fpga_picobello_pkg::axi_host_rsp_t int_rsp;

    // Read memory value and assert correctness
    assign int_addr = tg_cfg.mem_addr_base;
    assign int_golden_value = golden_value;
    picobello_read(int_addr, int_read_data, int_rsp);
    assert(int_rsp == axi_pkg::RESP_OKAY); 
    assert(int_read_data == int_golden_value);
  endtask

  // Program and launch traffic generators inside Picobello
  initial begin
    tb_axi_host_req_i = '{default: '0};
    tb_tg_cfg = '{default: '0};
    tb_timer_cfg = '{default: '0};

    // Wait for reset
    wait(rst_n);
    @(posedge clk); #5;

    // Initialize timer
    picobello_init_timer(tb_timer_cfg);
    wait(!tb_timer_cfg.reset_count_i); // Wait for reset to be deasserted

    //////////////////////////////////
    // Test: ClusterX0Y0 <-> L2Spm0 //
    //////////////////////////////////

    $display ("[%0tns] Test: ClusterX0Y0 <-> L2Spm0", $time);

    // Set address map
    tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::ClusterX0Y0;
    tb_tg_cfg.mem_port_id               = floo_picobello_noc_pkg::L2Spm0 - floo_picobello_noc_pkg::L2Spm0;
    tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + tb_tg_cfg.traffic_gen_port_id * 32'h0004_0000;    
    tb_tg_cfg.mem_addr_base             = 32'hD000_0000 + tb_tg_cfg.mem_port_id * 32'h0010_0000;

    // Set traffic generator parameters
    tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;
    tb_tg_cfg.TrafficGenIdx             = 32'h0000_0001;

    // Program traffic generator
    picobello_tg_cfg(tb_tg_cfg);

    // Start and read timer
    picobello_start_timer(tb_timer_cfg);

    // Run traffic generator
    picobello_tg_start(tb_tg_cfg);

    // Wait for termination
    picobello_tg_polling(tb_tg_cfg);

    // Stop and read timer
    picobello_stop_timer(tb_timer_cfg);
    $display ("[%0tns] - Timer value: %d", $time, counter_value_o);   

    ////////////////////////
    // Test: Run Them All //
    ////////////////////////

    $display ("[%0tns] Test: Run Them All", $time);

    // Iterate traffic generators and memory tiles to test NoC paths
    mem_tile_loop: for (int i_mem = 0; i_mem < picobello_pkg::NumMemTiles; i_mem++) begin
      
      // ---------------------------------------------------------------------------- //

      // Set memory address
      tb_tg_cfg.mem_port_id               = i_mem;  
      tb_tg_cfg.mem_addr_base             = 32'hD000_0000 + i_mem * 32'h0010_0000;

      // Set traffic generator parameters
      tb_tg_cfg.TrafficGenTrafficDim      = 32'h0000_0100;
      tb_tg_cfg.TrafficGenComputeDim      = 32'h0000_0100;

      // ---------------------------------------------------------------------------- //

      // Program traffic generators (Snitch clusters)
      tg_cfg_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        // Set traffic generator address and index
        tb_tg_cfg.traffic_gen_port_id       = i_tg;
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        tb_tg_cfg.TrafficGenIdx             = i_tg;
        picobello_tg_cfg(tb_tg_cfg);
      end

      // Program traffic generators (FhgSpu)
      tb_tg_cfg.traffic_gen_port_id       = floo_picobello_noc_pkg::FhgSpu;
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000;  
      tb_tg_cfg.TrafficGenIdx             = picobello_pkg::NumClusters;
      picobello_tg_cfg(tb_tg_cfg);

      // ---------------------------------------------------------------------------- //

      // Run traffic generators (Snitch clusters)
      tg_start_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_start(tb_tg_cfg);
      end

      // Run traffic generators (FhgSpu)
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000; 
      picobello_tg_start(tb_tg_cfg);

      #20us;

      // ---------------------------------------------------------------------------- //

      // Wait for termination (Snitch clusters)
      tg_wait_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        tb_tg_cfg.traffic_gen_addr_base     = 32'hC000_0000 + i_tg * 32'h0004_0000;  
        picobello_tg_polling(tb_tg_cfg);
      end

      // Wait for termination (FhgSpu)
      tb_tg_cfg.traffic_gen_addr_base     = 32'hE000_0000; 
      picobello_tg_polling(tb_tg_cfg);

      // ---------------------------------------------------------------------------- //

      // Print test infos (Snitch clusters)
      tg_info_loop: for (int i_tg = 0; i_tg < (picobello_pkg::NumClusters); i_tg++) begin
        $display ("[%0tns] - Mem-tile: %d", $time, i_mem);
        $display ("[%0tns] - TG-tile: %d", $time, i_tg);
      end
      
      // Print test infos (FhgSpu)
      $display ("[%0tns] - Mem-tile: %d", $time, i_mem);
      $display ("[%0tns] - TG-tile: %d", $time, picobello_pkg::NumClusters);

      // ---------------------------------------------------------------------------- //
    end

    #1us; 
    $finish();
  end

endmodule

