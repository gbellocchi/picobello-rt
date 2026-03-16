// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

`ifndef PICOBELLO_SIM_SVH_
`define PICOBELLO_SIM_SVH_

// Delay
`define wait_n_clk(n) repeat(n) @(posedge clk) // Delay

`endif // PICOBELLO_SIM_SVH_
