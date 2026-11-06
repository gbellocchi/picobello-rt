// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

module fpga_picobello_top_wrapper
  import cheshire_pkg::*;
(
% if fpga_target == 'xilvu9p':
  // Clocks and resets
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 rtc_i,
  // Boot mode
  input  logic [          1:0] boot_mode_i,
  // JTAG
  input  logic                 jtag_tck_i,
  input  logic                 jtag_trst_ni,
  input  logic                 jtag_tms_i,
  input  logic                 jtag_tdi_i,
  output logic                 jtag_tdo_o,
  output logic                 jtag_tdo_oe_o,
  // UART
  output logic                 uart_tx_o,
  input  logic                 uart_rx_i,
  // I2C
  output logic                 i2c_sda_o,
  input  logic                 i2c_sda_i,
  output logic                 i2c_sda_en_o,
  output logic                 i2c_scl_o,
  input  logic                 i2c_scl_i,
  output logic                 i2c_scl_en_o,
  // SPI host
  output logic                 spih_sck_o,
  output logic                 spih_sck_en_o,
  output logic [SpihNumCs-1:0] spih_csb_o,
  output logic [SpihNumCs-1:0] spih_csb_en_o,
  output logic [          3:0] spih_sd_o,
  output logic [          3:0] spih_sd_en_o,
  input  logic [          3:0] spih_sd_i,
  // GPIO
  input  logic [         31:0] gpio_i,
  output logic [         31:0] gpio_o,
  output logic [         31:0] gpio_en_o
% elif fpga_target == 'xilzu9eg':
  // TBD
% endif
);

% if fpga_target == 'xilvu9p':
  picobello_top i_picobello_top (
    .clk_i,
    .rst_ni,
    .test_mode_i         (1'b0),
    .boot_mode_i,
    .rtc_i,
    // JTAG
    .jtag_tck_i,
    .jtag_trst_ni,
    .jtag_tms_i,
    .jtag_tdi_i,
    .jtag_tdo_o,
    .jtag_tdo_oe_o,
    // UART (no modem flow control)
    .uart_tx_o,
    .uart_rx_i,
    .uart_rts_no         (),
    .uart_dtr_no         (),
    .uart_cts_ni         (1'b0),
    .uart_dsr_ni         (1'b0),
    .uart_dcd_ni         (1'b0),
    .uart_rin_ni         (1'b0),
    // I2C
    .i2c_sda_o,
    .i2c_sda_i,
    .i2c_sda_en_o,
    .i2c_scl_o,
    .i2c_scl_i,
    .i2c_scl_en_o,
    // SPI host
    .spih_sck_o,
    .spih_sck_en_o,
    .spih_csb_o,
    .spih_csb_en_o,
    .spih_sd_o,
    .spih_sd_en_o,
    .spih_sd_i,
    // GPIO
    .gpio_i,
    .gpio_o,
    .gpio_en_o,
    // Serial link (not available on FPGA)
    .slink_rcv_clk_i     ('0),
    .slink_rcv_clk_o     (),
    .slink_i             ('0),
    .slink_o             (),
    // DRAM serial link (not available on FPGA)
    .dram_slink_rcv_clk_i('0),
    .dram_slink_rcv_clk_o(),
    .dram_slink_i        ('0),
    .dram_slink_o        ()
  );
% elif fpga_target == 'xilzu9eg':
  // TBD
% endif

endmodule
