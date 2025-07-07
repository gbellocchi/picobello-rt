# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# # TB top
# add wave -noupdate -group {tb} {/tb_picobello_fpga/*}

# # TB timer
# add wave -noupdate -group {tb_timer} {/tb_picobello_fpga/counter_i/*}

# # DUT top
# add wave -noupdate -group {picobello} -group {top} {/tb_picobello_fpga/dut/*}

# # AXI4 host interface
# add wave -noupdate -group {picobello} -group {host} -group {ext_axi_host_req_i} {/tb_picobello_fpga/dut/ext_axi_host_req_i}
# add wave -noupdate -group {picobello} -group {host} -group {ext_axi_host_rsp_o} {/tb_picobello_fpga/dut/ext_axi_host_rsp_o}

# # AXI4 tg configuration interface
# add wave -noupdate -group {picobello} -group {host} -group {axi_tg_cfg_req_i} {/tb_picobello_fpga/dut/axi_tg_cfg_req_i}
# add wave -noupdate -group {picobello} -group {host} -group {axi_tg_cfg_rsp_o} {/tb_picobello_fpga/dut/axi_tg_cfg_rsp_o}

# # Host AXI4-Lite interface
# add wave -noupdate -group {picobello} -group {host} -group {axi_lite_tg_cfg_req_i} {/tb_picobello_fpga/dut/axi_lite_tg_cfg_req_i}
# add wave -noupdate -group {picobello} -group {host} -group {axi_lite_tg_cfg_rsp_o} {/tb_picobello_fpga/dut/axi_lite_tg_cfg_rsp_o}

# FPGA host tile
add wave -noupdate -group {picobello} -group {host_tile} {/tb_picobello_fpga/dut/i_fpga_host_tile/*}
add wave -noupdate -group {picobello} -group {host_tile} -group {router} {/tb_picobello_fpga/dut/i_fpga_host_tile/i_router/*}
add wave -noupdate -group {picobello} -group {host_tile} -group {ni} {/tb_picobello_fpga/dut/i_fpga_host_tile/i_chimney/*}

# All routers
set dim_x_cl 8
set dim_y_cl 16

# Cluster tiles
set dim_x_cl 1
set dim_y_cl 16

for {set idx 0} {$idx < [expr {$dim_x_cl * $dim_y_cl}]} {incr idx} {
    set y [expr {$idx % $dim_y_cl}]
    set x [expr {int($idx / $dim_y_cl)}]
    set tile_path "/tb_picobello_fpga/dut/gen_clusters\[$idx\]/i_cluster_tg_tile"

    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" ${tile_path}/*
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {router} ${tile_path}/i_router/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {ni} ${tile_path}/i_chimney/*

    # # Traffic generator
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {wrapper} ${tile_path}/i_axi_hls_tg_wrapper/*
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {top} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg/*
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {regfile} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*

    # Register file signal chain
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {xbar} ${tile_path}/i_tg_tile_cfg_xbar/*
    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_data_converter_tg_tile_cfg/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[1]} ${tile_path}/gen_tg_tile_cfg_axi_lite[1]/i_axi_data_converter_tg_tile_cfg/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[2]} ${tile_path}/gen_tg_tile_cfg_axi_lite[2]/i_axi_data_converter_tg_tile_cfg/*

    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {addr_converter[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_addr_converter_tg_tile_cfg/*

    add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_to_axi_lite_tg_tile_cfg/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[1]} ${tile_path}/gen_tg_tile_cfg_axi_lite[1]/i_axi_to_axi_lite_tg_tile_cfg/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[2]} ${tile_path}/gen_tg_tile_cfg_axi_lite[2]/i_axi_to_axi_lite_tg_tile_cfg/*

    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_lite_to_reg_narrow} ${tile_path}/i_axi_lite_to_reg_narrow/*
    # add wave -noupdate -group {picobello} -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_lite_to_reg_wide} ${tile_path}/i_axi_lite_to_reg_wide/*
}

# Memory tiles
set dim_x_mem 1
set dim_y_mem 16

for {set idx 0} {$idx < [expr {$dim_x_mem * $dim_y_mem}]} {incr idx} {
    set y [expr {$idx % $dim_y_mem}]
    set x [expr {int($idx / $dim_y_mem)}]
    set tile_path "/tb_picobello_fpga/dut/gen_memtile\[$idx\]/i_mem_tile"

    # add wave -noupdate -group {picobello} -group "mem_tile[$x][$y]" ${tile_path}/*
    add wave -noupdate -group {picobello} -group "mem_tile[$x][$y]" -group {router} ${tile_path}/i_router/*
    # add wave -noupdate -group {picobello} -group "mem_tile[$x][$y]" -group {ni} ${tile_path}/i_chimney/*
    # add wave -noupdate -group {picobello} -group "mem_tile[$x][$y]" -group {axi_to_obi} ${tile_path}/i_axi_to_obi/*
}

# Dummy tiles
set dim_x_dummy 5
set dim_y_dummy 16

for {set idx 0} {$idx < [expr {$dim_x_dummy * $dim_y_dummy}]} {incr idx} {
    set y [expr {$idx % $dim_y_dummy}]
    set x [expr {int($idx / $dim_y_dummy)}]
    set tile_path "/tb_picobello_fpga/dut/gen_dummytiles\[$idx\]/i_dummy_tile"
    # add wave -noupdate -group {picobello} -group "dummy_tile[$x][$y]" ${tile_path}/*
    add wave -noupdate -group {picobello} -group "dummy_tile[$x][$y]" -group {router} ${tile_path}/i_router/*
}

# # SPU tile
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} {/tb_picobello_fpga/dut/i_fhg_spu_tile/*}
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {ni} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_chimney/*}
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {router} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_router/*}
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {wrapper} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/*}
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {top} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/*}
# add wave -noupdate -group {picobello} -group {fhg_spu_tile} -group {traffic_gen} -group {regfile} {/tb_picobello_fpga/dut/i_fhg_spu_tile/i_axi_hls_tg_wrapper/i_axi_hls_tg/control_s_axi_U/*}
