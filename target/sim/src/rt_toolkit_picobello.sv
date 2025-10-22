// Copyright 2025 University of Modena and Reggio Emilia.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

import fpga_picobello_pkg::*;

module rt_toolkit (
  input logic       clk,
  input logic       rst_n
);

  ///////////
  //  DPI  //
  ///////////

  import "DPI-C" context task hello_world();
  import "DPI-C" context task axi_test_sequence();
  
  // DPI-C tasks for AXI4 interface control
  export "DPI-C" task set_cluster_tg_start;
  export "DPI-C" task sv_picobello_write;
//   export "DPI-C" task sv_picobello_read;
//   export "DPI-C" task sv_wait_clocks;

task set_cluster_tg_start(input int cluster_id, input bit value);
    case (cluster_id)
        0: dut.gen_clusters[0].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = value;
        1: dut.gen_clusters[1].i_cluster_tg_tile.i_axi_hls_tg_wrapper.i_axi_hls_tg_read.control_s_axi_U.int_ap_start = value;
    endcase
endtask


  // SystemVerilog wrapper tasks callable from C
  task sv_picobello_write(
    input longint unsigned addr,
    input longint unsigned data,
    input int unsigned strb,
    output int unsigned resp
  );
    fpga_picobello_pkg::axi_host_addr_t write_addr;
    fpga_picobello_pkg::axi_host_data_t write_data;
    fpga_picobello_pkg::axi_host_strb_t write_strb;
    fpga_picobello_pkg::axi_host_rsp_t write_rsp;
    
    write_addr = addr[31:0];
    write_data = data[31:0];
    write_strb = strb[7:0];
    
    // Call the existing task from tb_picobello_fpga_tasks.svh
    $root.tb_picobello_fpga.picobello_write(write_addr, write_data, write_strb, write_rsp);
    
    resp = write_rsp;
  endtask

//   task sv_picobello_read(
//     input longint unsigned addr,
//     output longint unsigned data,
//     output int unsigned resp
//   );
//     fpga_picobello_pkg::axi_host_addr_t read_addr;
//     fpga_picobello_pkg::axi_host_data_t read_data;
//     fpga_picobello_pkg::axi_host_rsp_t read_rsp;
    
//     read_addr = addr[31:0];
    
//     // Call the existing task from tb_picobello_fpga_tasks.svh
//     $root.tb_picobello_fpga.picobello_read(read_addr, read_data, read_rsp);
    
//     data = {32'b0, read_data};
//     resp = read_rsp;
//   endtask

//   task sv_wait_clocks(input int unsigned num_clocks);
//     repeat(num_clocks) @(posedge clk);
//   endtask

endmodule