// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Wide-plane NoC link tracer, `include`d inside the testbench module after the DUT.
//
// While `noc_trace_en` is high it writes one row per packet (all flits up to hdr.last, i.e. one
// AW + FL W beats per AXI-REALM fragment of a write) on every router output and local input to
// <VSIM_LOG>/test<noc_trace_test>_noc_link_trace.csv:
//   t0, t1, x, y, port, src_x, src_y, dst_x, dst_y, ch, flits
// t0/t1: cycle of the first/last flit handshake, counted from the rising edge of noc_trace_en.
// port: 0..3 router output N/E/S/W, 4 local output (ejection), 5 local input (injection).
// ch: floo_pkg::nw_ch_e of the first flit (WideAw for writes, WideR for read data).
// It is the RTL reference ("golden") trace for the Python model (runs/py_model_bw/golden.py).

localparam int unsigned TrPorts        = 6;
localparam int unsigned TrMaxCycles    = 4_000_000; // stop tracing after this many cycles

bit          noc_trace_en;
int unsigned noc_trace_test;
int unsigned noc_trace_t0_timer;       // tb timer value at the start of the trace

bit                           tr_hs  [MeshDim.x][MeshDim.y][TrPorts];
floo_picobello_noc_pkg::hdr_t tr_hdr [MeshDim.x][MeshDim.y][TrPorts];

// Mesh links: output d of router (x,y) handshakes with the input of its neighbour
for (genvar x = 0; x < MeshDim.x; x++) begin : gen_tr_x
  for (genvar y = 0; y < MeshDim.y; y++) begin : gen_tr_y
    for (genvar d = 0; d < 4; d++) begin : gen_tr_dir
      assign tr_hs[x][y][d]  = dut.floo_wide_out[x][y][d].valid & dut.floo_wide_in[x][y][d].ready;
      assign tr_hdr[x][y][d] = dut.floo_wide_out[x][y][d].wide.generic.hdr;
    end
  end
end

// Local ports of the cluster and memory tiles
for (genvar c = 0; c < NumClusters; c++) begin : gen_tr_cl
  localparam id_t Id = Sam[c + ClusterX0Y0SamIdx].idx;
  assign tr_hs[Id.x][Id.y][4]  = dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_out[Eject].valid &
                                 dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_in[Eject].ready;
  assign tr_hdr[Id.x][Id.y][4] = dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_out[Eject].wide.generic.hdr;
  assign tr_hs[Id.x][Id.y][5]  = dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_in[Eject].valid &
                                 dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_out[Eject].ready;
  assign tr_hdr[Id.x][Id.y][5] = dut.gen_clusters[c].i_cluster_rt_tile.router_floo_wide_in[Eject].wide.generic.hdr;
end
for (genvar m = 0; m < NumMemTiles; m++) begin : gen_tr_mem
  localparam id_t Id = Sam[m + L2Spm0SamIdx].idx;
  assign tr_hs[Id.x][Id.y][4]  = dut.gen_memtile[m].i_mem_tile.router_floo_wide_out[Eject].valid &
                                 dut.gen_memtile[m].i_mem_tile.router_floo_wide_in[Eject].ready;
  assign tr_hdr[Id.x][Id.y][4] = dut.gen_memtile[m].i_mem_tile.router_floo_wide_out[Eject].wide.generic.hdr;
  assign tr_hs[Id.x][Id.y][5]  = dut.gen_memtile[m].i_mem_tile.router_floo_wide_in[Eject].valid &
                                 dut.gen_memtile[m].i_mem_tile.router_floo_wide_out[Eject].ready;
  assign tr_hdr[Id.x][Id.y][5] = dut.gen_memtile[m].i_mem_tile.router_floo_wide_in[Eject].wide.generic.hdr;
end

initial begin : p_noc_trace
  automatic int          fd;
  automatic int unsigned t;
  automatic string       dir, path;
  automatic int unsigned pkt_t0 [MeshDim.x][MeshDim.y][TrPorts];
  automatic int unsigned pkt_n  [MeshDim.x][MeshDim.y][TrPorts];
  automatic floo_picobello_noc_pkg::hdr_t pkt_hdr [MeshDim.x][MeshDim.y][TrPorts];
  forever begin
    @(posedge noc_trace_en);
    if (!$value$plusargs("VSIM_LOG=%s", dir)) continue;
    $sformat(path, "%s/test%0d_noc_link_trace.csv", dir, noc_trace_test);
    fd = $fopen(path, "w");
    $fwrite(fd, "# floomodel-trace: noc_link/1\n");
    $fwrite(fd, "# trace_start_timer: %0d\n", noc_trace_t0_timer);
    $fwrite(fd, "t0,t1,x,y,port,src_x,src_y,dst_x,dst_y,ch,flits\n");
    t = 0;
    foreach (pkt_n[x, y, p]) pkt_n[x][y][p] = 0;
    while (noc_trace_en && t < TrMaxCycles) begin
      @(posedge clk);
      t++;
      foreach (pkt_n[x, y, p]) begin
        if (tr_hs[x][y][p] !== 1'b1) continue;
        if (pkt_n[x][y][p] == 0) begin
          pkt_t0[x][y][p]  = t;
          pkt_hdr[x][y][p] = tr_hdr[x][y][p];
        end
        pkt_n[x][y][p]++;
        if (tr_hdr[x][y][p].last) begin
          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", pkt_t0[x][y][p], t, x, y, p,
                  pkt_hdr[x][y][p].src_id.x, pkt_hdr[x][y][p].src_id.y,
                  pkt_hdr[x][y][p].dst_id.x, pkt_hdr[x][y][p].dst_id.y,
                  pkt_hdr[x][y][p].axi_ch, pkt_n[x][y][p]);
          pkt_n[x][y][p] = 0;
        end
      end
    end
    $fclose(fd);
    wait (!noc_trace_en);
  end
end
