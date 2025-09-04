# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Parameters
set dim_x_cl 4
set dim_y_cl 4
set n_cl [expr {$dim_x_cl * $dim_y_cl}]

set dim_x_mem 1
set dim_y_mem 32

set dim_x_dummy 5
set dim_y_dummy 16

# TB top
add wave -noupdate -group {tb} {/tb_picobello_fpga/*}

# TB BW monitors
for {set idx 0} {$idx < $n_cl} {incr idx} {
    set y [expr {$idx % $dim_y_cl}]
    set x [expr {int($idx / $dim_y_cl)}]

    add wave -noupdate -group {tb_bw_monitor} -group "gen_cl_bw_monitor[$idx]" /tb_picobello_fpga/gen_cl_bw_monitor\[$idx\]/i_axi_bw_monitor/*
    add wave -noupdate -group {tb_bw_monitor} -group "gen_noc_bw_monitor[$idx]" /tb_picobello_fpga/gen_noc_bw_monitor\[$idx\]/i_axi_bw_monitor/*
}

# TB timer
add wave -noupdate -group {tb_timer} {/tb_picobello_fpga/timer_i/*}

# DUT top
add wave -noupdate -group {top} {/tb_picobello_fpga/dut/*}

# FPGA host tile
add wave -noupdate -group {host_tile} {/tb_picobello_fpga/dut/i_fpga_host_tile/*}
add wave -noupdate -group {host_tile} -group {router} {/tb_picobello_fpga/dut/i_fpga_host_tile/i_router/*}
add wave -noupdate -group {host_tile} -group {ni} {/tb_picobello_fpga/dut/i_fpga_host_tile/i_chimney/*}

# Cluster tiles
for {set idx 0} {$idx < $n_cl} {incr idx} {
    set y [expr {$idx % $dim_y_cl}]
    set x [expr {int($idx / $dim_y_cl)}]
    set tile_path "/tb_picobello_fpga/dut/gen_clusters\[$idx\]/i_cluster_tg_tile"

    # add wave -noupdate -group "cluster_tile[$x][$y]" ${tile_path}/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {router} -group {top} ${tile_path}/i_router/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {top} ${tile_path}/i_chimney/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {narrow_r_rob} ${tile_path}/i_chimney/i_narrow_r_rob/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {narrow_b_rob} ${tile_path}/i_chimney/i_narrow_b_rob/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {wide_r_rob} ${tile_path}/i_chimney/i_wide_r_rob/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {wide_b_rob} ${tile_path}/i_chimney/i_wide_b_rob/*
    
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {req_wormhole_arbiter} ${tile_path}/i_chimney/i_req_wormhole_arbiter/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {rsp_wormhole_arbiter} ${tile_path}/i_chimney/i_rsp_wormhole_arbiter/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {wide_wormhole_arbiter} ${tile_path}/i_chimney/i_wide_wormhole_arbiter/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {narrow_meta_buffer} ${tile_path}/i_chimney/gen_narrow_mgr_port/i_narrow_meta_buffer/*
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {ni} -group {wide_meta_buffer} ${tile_path}/i_chimney/gen_wide_mgr_port/i_wide_meta_buffer/*

    # # Traffic generator
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {axi_tg_wide_out} ${tile_path}/i_axi_hls_tg_wrapper/axi_tg_wide_out/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {axi_tg_wide_rw_out[READ]} ${tile_path}/i_axi_hls_tg_wrapper/axi_tg_wide_rw_out[0]/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {axi_tg_wide_rw_out[WRITE]} ${tile_path}/i_axi_hls_tg_wrapper/axi_tg_wide_rw_out[1]/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {rw_join[OUT]} ${tile_path}/i_axi_hls_tg_wrapper/i_rw_join_out/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {rw_join[DUMMY]} ${tile_path}/i_axi_hls_tg_wrapper/i_rw_join_dummy/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {r_top} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_read/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {r_regfile} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_read/control_s_axi_U/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {w_top} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_write/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {traffic_gen} -group {w_regfile} ${tile_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_write/control_s_axi_U/*

    # Register file signal chain
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {xbar} ${tile_path}/i_tg_tile_cfg_xbar/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_data_converter_tg_tile_cfg/*
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[1]} ${tile_path}/gen_tg_tile_cfg_axi_lite[1]/i_axi_data_converter_tg_tile_cfg/*
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {data_converter[2]} ${tile_path}/gen_tg_tile_cfg_axi_lite[2]/i_axi_data_converter_tg_tile_cfg/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {addr_converter[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_addr_converter_tg_tile_cfg/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[0]} ${tile_path}/gen_tg_tile_cfg_axi_lite[0]/i_axi_to_axi_lite_tg_tile_cfg/*
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[1]} ${tile_path}/gen_tg_tile_cfg_axi_lite[1]/i_axi_to_axi_lite_tg_tile_cfg/*
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[2]} ${tile_path}/gen_tg_tile_cfg_axi_lite[2]/i_axi_to_axi_lite_tg_tile_cfg/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[3]} ${tile_path}/gen_tg_tile_cfg_axi_lite[3]/i_axi_to_axi_lite_tg_tile_cfg/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[3]} -group {top} ${tile_path}/gen_tg_tile_cfg_axi_lite[3]/i_axi_to_axi_lite_tg_tile_cfg/i_axi_to_axi_lite/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[3]} -group {axi_atop_filter} ${tile_path}/gen_tg_tile_cfg_axi_lite[3]/i_axi_to_axi_lite_tg_tile_cfg/i_axi_to_axi_lite/i_axi_atop_filter/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[3]} -group {axi_burst_splitter} ${tile_path}/gen_tg_tile_cfg_axi_lite[3]/i_axi_to_axi_lite_tg_tile_cfg/i_axi_to_axi_lite/i_axi_burst_splitter/i_axi_burst_splitter_gran/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_to_axi_lite[3]} -group {axi_to_axi_lite_id_reflect} ${tile_path}/gen_tg_tile_cfg_axi_lite[3]/i_axi_to_axi_lite_tg_tile_cfg/i_axi_to_axi_lite/i_axi_to_axi_lite_id_reflect/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {tg_tile_cfg} -group {axi_lite_to_reg_wide} ${tile_path}/i_axi_lite_to_reg_wide/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_rt_unit_wide_top} ${tile_path}/i_axi_rt_unit_wide/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_isolate} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_isolate/*
    
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_gran_burst_splitter} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_gran_burst_splitter/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_gran_burst_splitter_aw_chan} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_gran_burst_splitter/i_axi_gran_burst_splitter_aw_chan/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_gran_burst_splitter_ar_chan} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_gran_burst_splitter/i_axi_gran_burst_splitter_ar_chan/*

    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_write_buffer} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_write_buffer/*
    
    # add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_isolate_tail} ${tile_path}/i_axi_rt_unit_wide/gen_rt_units[0]/i_axi_rt_unit/i_axi_isolate_tail/*

    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_rt_regbus_guard} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_regbus_guard/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_rt_regbus_guard} -group {reg_demux} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_regbus_guard/i_reg_demux/*
    add wave -noupdate -group "cluster_tile[$x][$y]" -group {axi_rt} -group {axi_rt_reg_top} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_reg_top/*
}

# Group all TGs together for direct comparison
for {set idx 0} {$idx < [expr {$dim_x_cl * $dim_y_cl}]} {incr idx} {
    set y [expr {$idx % $dim_y_cl}]
    set x [expr {int($idx / $dim_y_cl)}]
    set tile_path "/tb_picobello_fpga/dut/gen_clusters\[$idx\]/i_cluster_tg_tile"
    
    add wave -noupdate -group {tg_out_all} -group "tg[$idx]" ${tile_path}/i_axi_hls_tg_wrapper/axi_tg_wide_out/*
}

# Memory tiles
for {set idx 0} {$idx < [expr {$dim_x_mem * $dim_y_mem}]} {incr idx} {
    set y [expr {$idx % $dim_y_mem}]
    set x [expr {int($idx / $dim_y_mem)}]
    set tile_path "/tb_picobello_fpga/dut/gen_memtile\[$idx\]/i_mem_tile"

    add wave -noupdate -group "mem_tile[$x][$y]" ${tile_path}/*
    add wave -noupdate -group "mem_tile[$x][$y]" -group {router} -group {top} ${tile_path}/i_router/*
    add wave -noupdate -group "mem_tile[$x][$y]" -group {router} -group {req_floo_router} ${tile_path}/i_router/i_req_floo_router/*
    add wave -noupdate -group "mem_tile[$x][$y]" -group {router} -group {rsp_floo_router} ${tile_path}/i_router/i_rsp_floo_router/*
    add wave -noupdate -group "mem_tile[$x][$y]" -group {router} -group {wide_req_floo_router} ${tile_path}/i_router/i_wide_req_floo_router/*
    add wave -noupdate -group "mem_tile[$x][$y]" -group {ni} -group {top} ${tile_path}/i_chimney/*
    # add wave -noupdate -group "mem_tile[$x][$y]" -group {axi_to_obi} ${tile_path}/i_axi_to_obi/*
}

# # Dummy tiles
# for {set idx 0} {$idx < [expr {$dim_x_dummy * $dim_y_dummy}]} {incr idx} {
#     set y [expr {$idx % $dim_y_dummy}]
#     set x [expr {int($idx / $dim_y_dummy)}]
#     set tile_path "/tb_picobello_fpga/dut/gen_dummytiles\[$idx\]/i_dummy_tile"
#     # add wave -noupdate -group "dummy_tile[$x][$y]" ${tile_path}/*
#     add wave -noupdate -group "dummy_tile[$x][$y]" -group {router} -group {top} ${tile_path}/i_router/*
# }

TreeUpdate [SetDefaultTree]
quietly wave cursor active 1
configure wave -namecolwidth 271
configure wave -valuecolwidth 483
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update