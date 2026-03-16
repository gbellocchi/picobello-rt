# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

# Parameters
set n_cl 4
# set n_cl 9
set n_core 8
set n_core_regfiles 4
set n_mem 1
# set n_mem 8
set use_hls_tg 0

# TB top
add wave -noupdate -group {tb} {/tb_picobello_fpga_fair/*}

# TB BW monitors
for {set cl 0} {$cl < $n_cl} {incr cl} {
    for {set co 0} {$co < $n_core} {incr co} {
        add wave -noupdate -group {cl_bw_monitor} -group "gen_cl_bw_monitor[$cl][$co]" /tb_picobello_fpga_fair/gen_cl_bw_monitor_loop_0\[$cl\]/gen_cl_bw_monitor_loop_1\[$co\]/i_axi_bw_monitor/*
    }
}

# TB timer
add wave -noupdate -group {tb_timer} {/tb_picobello_fpga_fair/timer_i/*}

# DUT top
add wave -noupdate -group {top} {/tb_picobello_fpga_fair/dut/*}

# FPGA host tile
add wave -noupdate -group {host_tile} {/tb_picobello_fpga_fair/dut/i_fpga_host_tile/*}
add wave -noupdate -group {host_tile} -group {router} {/tb_picobello_fpga_fair/dut/i_fpga_host_tile/i_router/*}
add wave -noupdate -group {host_tile} -group {ni} {/tb_picobello_fpga_fair/dut/i_fpga_host_tile/i_chimney/*}

# Cluster tiles
for {set cl 0} {$cl < $n_cl} {incr cl} {
    set tile_path "/tb_picobello_fpga_fair/dut/gen_clusters\[$cl\]/i_cluster_rt_tile"

    add wave -noupdate -group "cluster_tile[$cl]" -group {top} ${tile_path}/*

    add wave -noupdate -group "cluster_tile[$cl]" -group {router} -group {top} ${tile_path}/i_router/*

    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {top} ${tile_path}/i_chimney/*

    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {narrow_r_rob} ${tile_path}/i_chimney/i_narrow_r_rob/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {narrow_b_rob} ${tile_path}/i_chimney/i_narrow_b_rob/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {wide_r_rob} ${tile_path}/i_chimney/i_wide_r_rob/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {wide_b_rob} ${tile_path}/i_chimney/i_wide_b_rob/*
    
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {req_wormhole_arbiter} ${tile_path}/i_chimney/i_req_wormhole_arbiter/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {rsp_wormhole_arbiter} ${tile_path}/i_chimney/i_rsp_wormhole_arbiter/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {wide_wormhole_arbiter} ${tile_path}/i_chimney/i_wide_wormhole_arbiter/*

    add wave -noupdate -group "cluster_tile[$cl]" -group {ni} -group {narrow_meta_buffer} ${tile_path}/i_chimney/gen_narrow_mgr_port/i_narrow_meta_buffer/*

    if {$use_hls_tg} {
        # Traffic generator
        for {set co 0} {$co < $n_core} {incr co} {
            set tile_core_path "${tile_path}/i_axi_traffic_gen_wrapper/gen_traffic_generators\[$co\]/gen_hls_dma"

            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {axi_tg_wide_out} ${tile_core_path}/i_axi_hls_tg_wrapper/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {axi_tg_wide_rw_out[READ]} ${tile_core_path}/i_axi_hls_tg_wrapper/axi_tg_wide_rw_out[0]/*

            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {axi_tg_wide_rw_out[WRITE]} ${tile_core_path}/i_axi_hls_tg_wrapper/axi_tg_wide_rw_out[1]/*

            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {rw_join[OUT]} ${tile_core_path}/i_axi_hls_tg_wrapper/i_rw_join_out/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {rw_join[DUMMY]} ${tile_core_path}/i_axi_hls_tg_wrapper/i_rw_join_dummy/*

            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {r_top} ${tile_core_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_read/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {r_regfile} ${tile_core_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_read/control_s_axi_U/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {w_top} ${tile_core_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_write/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "traffic_gen[$co]" -group {w_regfile} ${tile_core_path}/i_axi_hls_tg_wrapper/i_axi_hls_tg_write/control_s_axi_U/*
        }
    } else {
        # DMA test node
        for {set co 0} {$co < $n_core} {incr co} {
            set tile_core_path "${tile_path}/i_axi_traffic_gen_wrapper/gen_traffic_generators\[$co\]/gen_floo_dma"

            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {top} ${tile_core_path}/i_wide_dma_node/*
                        add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {axi_rw_join} ${tile_core_path}/i_wide_dma_node/i_axi_rw_join/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {xbar} ${tile_core_path}/i_wide_dma_node/i_xbar/*

            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {idma_backend} ${tile_core_path}/i_wide_dma_node/i_idma_backend/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {idma_transport_layer} -group {top} ${tile_core_path}/i_wide_dma_node/i_idma_backend/i_idma_transport_layer/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {idma_transport_layer} -group {idma_axi_read} ${tile_core_path}/i_wide_dma_node/i_idma_backend/i_idma_transport_layer/i_idma_axi_read/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {idma_transport_layer} -group {idma_axi_write} ${tile_core_path}/i_wide_dma_node/i_idma_backend/i_idma_transport_layer/i_idma_axi_write/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {floo_dma} -group {idma_transport_layer} -group {idma_dataflow_element} ${tile_core_path}/i_wide_dma_node/i_idma_backend/i_idma_transport_layer/i_dataflow_element/*

            # add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {axi_isolate} ${tile_core_path}/i_axi_isolate/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {axi_lite_to_reg_read} ${tile_core_path}/i_axi_lite_to_reg_read/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {axi_lite_to_reg_write} ${tile_core_path}/i_axi_lite_to_reg_write/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {axi_lite_to_reg_compute} ${tile_core_path}/i_axi_lite_to_reg_compute/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {reg_top_read} ${tile_core_path}/i_reg_top_read/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {reg_top_write} ${tile_core_path}/i_reg_top_write/*
            add wave -noupdate -group "cluster_tile[$cl]" -group "floo_dma_test_node[$co]" -group {reg_top_compute} ${tile_core_path}/i_reg_top_compute/*
        }
    }

    # Realm tile - XBAR - NI --> Cores
    add wave -noupdate -group "cluster_tile[$cl]" -group {xbar_ni2cores} ${tile_path}/i_rt_tile_ni2cores_xbar/*

    # Realm tile - XBAR - Core --> Register file
    for {set co 0} {$co < $n_core} {incr co} {
        add wave -noupdate -group "cluster_tile[$cl]" -group "xbar_core2regfile[$co]" ${tile_path}/gen_rt_tile_core2regfile_xbar\[$co\]/i_rt_tile_core2regfile_xbar/*
    }

    # AXI-Realm
    add wave -noupdate -group "cluster_tile[$cl]" -group {axi_rt} -group {axi_rt_unit_wide_top} ${tile_path}/i_axi_rt_unit_wide/*

    for {set co 0} {$co < $n_core} {incr co} {
        set tile_core_path "${tile_path}/i_axi_rt_unit_wide/gen_rt_units\[$co\]/i_axi_rt_unit"

        add wave -noupdate -group "cluster_tile[$cl]" -group {axi_rt} -group "axi_rt_unit_wide[$co]" ${tile_core_path}/*
    }

    add wave -noupdate -group "cluster_tile[$cl]" -group {axi_rt} -group {axi_rt_regbus_guard} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_regbus_guard/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {axi_rt} -group {axi_rt_regbus_guard} -group {reg_demux} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_regbus_guard/i_reg_demux/*
    add wave -noupdate -group "cluster_tile[$cl]" -group {axi_rt} -group {axi_rt_reg_top} ${tile_path}/i_axi_rt_unit_wide/i_axi_rt_reg_top/*
}

# Memory tiles
for {set mem 0} {$mem < $n_mem} {incr mem} {
    set tile_path "/tb_picobello_fpga_fair/dut/gen_memtile\[$mem\]/i_mem_tile"

    add wave -noupdate -group "mem_tile[$mem]" -group {top} ${tile_path}/*

    add wave -noupdate -group "mem_tile[$mem]" -group {router} -group {top} ${tile_path}/i_router/*

    add wave -noupdate -group "mem_tile[$mem]" -group {router} -group {req_floo_router} ${tile_path}/i_router/i_req_floo_router/*
    add wave -noupdate -group "mem_tile[$mem]" -group {router} -group {rsp_floo_router} ${tile_path}/i_router/i_rsp_floo_router/*
    add wave -noupdate -group "mem_tile[$mem]" -group {router} -group {wide_req_floo_router} ${tile_path}/i_router/i_wide_req_floo_router/*
    
    for {set in_port 0} {$in_port < 5} {incr in_port} {
        for {set v_chan 0} {$v_chan < 1} {incr v_chan} {
            add wave -noupdate -group "mem_tile[$mem]" -group {router} -group {wide_req_floo_router} -group "route_select\[${in_port}\]\[${v_chan}\]" ${tile_path}/i_router/i_wide_req_floo_router/gen_input\[${in_port}\]/gen_virt_input\[${v_chan}\]/i_route_select/*
        }
    }

    add wave -noupdate -group "mem_tile[$mem]" -group {ni} -group {top} ${tile_path}/i_chimney/*

    add wave -noupdate -group "mem_tile[$mem]" -group {ni} -group {wide_wormhole_arbiter} ${tile_path}/i_chimney/i_wide_wormhole_arbiter/*
    add wave -noupdate -group "mem_tile[$mem]" -group {ni} -group {wide_meta_buffer} ${tile_path}/i_chimney/gen_wide_mgr_port/i_wide_meta_buffer/*

    # # FPGA L2 memory interface
    # add wave -noupdate -group "mem_tile[$mem]" -group {l2_slv_cut} ${tile_path}/i_l2_slv_cut/*
    # add wave -noupdate -group "mem_tile[$mem]" -group {axi2mem} ${tile_path}/i_axi2mem/*

    # Picobello L2 memory interface
    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {top} ${tile_path}/i_floo_nw_join/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_narrow_iw_converter} ${tile_path}/i_floo_nw_join/i_axi_narrow_iw_converter/*
    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_narrow_dw_converter} ${tile_path}/i_floo_nw_join/i_axi_narrow_dw_converter/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_wide_iw_converter} ${tile_path}/i_floo_nw_join/i_axi_wide_iw_converter/*
    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_wide_dw_converter} ${tile_path}/i_floo_nw_join/i_axi_wide_dw_converter/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {top} ${tile_path}/i_floo_nw_join/i_axi_mux/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {axi_id_prepend[0]} ${tile_path}/i_floo_nw_join/i_axi_mux/gen_mux/gen_id_prepend[0]/i_id_prepend/gen_id_prepend[0]/gen_prepend/#ALWAYS#86/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {axi_id_prepend[1]} ${tile_path}/i_floo_nw_join/i_axi_mux/gen_mux/gen_id_prepend[1]/i_id_prepend/gen_id_prepend[0]/gen_prepend/#ALWAYS#86/*

    # # keep both as top
    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {ar_rr_arbiter} -group {top} ${tile_path}/i_floo_nw_join/i_axi_mux/gen_mux/i_ar_arbiter/*
    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {ar_rr_arbiter} -group {top} ${tile_path}/i_floo_nw_join/i_axi_mux/gen_mux/i_ar_arbiter/gen_arbiter/*

    # add wave -noupdate -group "mem_tile[$mem]" -group {floo_nw_join} -group {axi_mux} -group {ar_spill_reg} ${tile_path}/i_floo_nw_join/i_axi_mux/gen_mux/i_ar_spill_reg/*

    add wave -noupdate -group "mem_tile[$mem]" -group {axi_delay} ${tile_path}/i_axi_delay/*
    # add wave -noupdate -group "mem_tile[$mem]" -group {axi_delay} -group {axi_shift_ar} ${tile_path}/i_axi_delay/gen_delay_ar_channel/i_axi_shift_ar/*

    add wave -noupdate -group "mem_tile[$mem]" -group {axi_id_flattening} ${tile_path}/i_axi_id_flattening/*

    add wave -noupdate -group "mem_tile[$mem]" -group {axi_to_obi} -group {top} ${tile_path}/i_axi_to_obi/*
    add wave -noupdate -group "mem_tile[$mem]" -group {axi_to_obi} -group {read_write_demux} ${tile_path}/i_axi_to_obi/i_read_write_demux/*
    add wave -noupdate -group "mem_tile[$mem]" -group {axi_to_obi} -group {axi_to_mem_read} ${tile_path}/i_axi_to_obi/i_axi_to_mem_read/*
    add wave -noupdate -group "mem_tile[$mem]" -group {axi_to_obi} -group {axi_to_mem_write} ${tile_path}/i_axi_to_obi/i_axi_to_mem_write/*
    add wave -noupdate -group "mem_tile[$mem]" -group {axi_to_obi} -group {mux_banks} ${tile_path}/i_axi_to_obi/i_mux_banks/*

    add wave -noupdate -group "mem_tile[$mem]" -group {obi_atop_resolver} ${tile_path}/i_obi_atop_resolver/*
    add wave -noupdate -group "mem_tile[$mem]" -group {sram_shim_bank} ${tile_path}/i_sram_shim_bank/*
}

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