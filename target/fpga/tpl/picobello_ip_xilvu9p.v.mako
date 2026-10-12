// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

module picobello_ip (
  ${port('clk', 1, False)},\
  ${port('rst', 1, False, True)},\
  ${port('rtc', 1, False)},\
  ${port('boot_mode', 2, False)},\
  ${port('jtag_tck', 1, False)},\
  ${port('jtag_trst', 1, False, True)},\
  ${port('jtag_tms', 1, False)},\
  ${port('jtag_tdi', 1, False)},\
  ${port('jtag_tdo', 1, True)},\
  ${port('jtag_tdo_oe', 1, True)},\
  ${port('uart_tx', 1, True)},\
  ${port('uart_rx', 1, False)},\
  ${port('i2c_sda', 1, True)},\
  ${port('i2c_sda', 1, False)},\
  ${port('i2c_sda_en', 1, True)},\
  ${port('i2c_scl', 1, True)},\
  ${port('i2c_scl', 1, False)},\
  ${port('i2c_scl_en', 1, True)},\
  ${port('spih_sck', 1, True)},\
  ${port('spih_sck_en', 1, True)},\
  ${port('spih_csb', spih_num_cs, True)},\
  ${port('spih_csb_en', spih_num_cs, True)},\
  ${port('spih_sd', 4, True)},\
  ${port('spih_sd_en', 4, True)},\
  ${port('spih_sd', 4, False)},\
  ${port('gpio', 32, False)},\
  ${port('gpio', 32, True)},\
  ${port('gpio_en', 32, True)}
);

  fpga_picobello_top_wrapper i_picobello_top_wrapper (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .rtc_i         (rtc_i),
    .boot_mode_i   (boot_mode_i),
    .jtag_tck_i    (jtag_tck_i),
    .jtag_trst_ni  (jtag_trst_ni),
    .jtag_tms_i    (jtag_tms_i),
    .jtag_tdi_i    (jtag_tdi_i),
    .jtag_tdo_o    (jtag_tdo_o),
    .jtag_tdo_oe_o (jtag_tdo_oe_o),
    .uart_tx_o     (uart_tx_o),
    .uart_rx_i     (uart_rx_i),
    .i2c_sda_o     (i2c_sda_o),
    .i2c_sda_i     (i2c_sda_i),
    .i2c_sda_en_o  (i2c_sda_en_o),
    .i2c_scl_o     (i2c_scl_o),
    .i2c_scl_i     (i2c_scl_i),
    .i2c_scl_en_o  (i2c_scl_en_o),
    .spih_sck_o    (spih_sck_o),
    .spih_sck_en_o (spih_sck_en_o),
    .spih_csb_o    (spih_csb_o),
    .spih_csb_en_o (spih_csb_en_o),
    .spih_sd_o     (spih_sd_o),
    .spih_sd_en_o  (spih_sd_en_o),
    .spih_sd_i     (spih_sd_i),
    .gpio_i        (gpio_i),
    .gpio_o        (gpio_o),
    .gpio_en_o     (gpio_en_o)
  );

endmodule

<%
  # Definition of template-based functions to support generation
%>

<%def name="logic(width)">\
  <%
    if width == 1:
      typ = 'wire        '
    else:
      typ = "wire [%3d:0]" % (width - 1)
  %>
  ${typ}\
</%def>\
<%def name="port(name, width, output, active_low=False)">\
  <%
    if output:
      direction = 'output'
      suffix = 'o'
    else:
      direction = 'input '
      suffix = 'i'
    if width == 1:
      typ = '        '
    else:
      typ = "[%3d:0] " % (width - 1)
    if active_low:
      suffix = 'n' + suffix
    name = name + '_' + suffix
  %>
  % if width > 0:
  ${direction} ${typ} ${name}\
  % endif
</%def>\
