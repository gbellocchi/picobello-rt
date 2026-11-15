// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// AXI-REALM period probe, `include`d inside the testbench module after the DUT.
//
// Passively watches the write budget counter of every wide-plane AXI-REALM unit (region 0) and,
// while `realm_probe_en` is high, logs one row per elapsed period to
// <VSIM_LOG>/test<realm_probe_test>_realm_periods_cl_<c>_core_<j>.txt:
//   period, t_start, t_end, frags, bytes_admitted, bytes_charged, budget_left, isolated_cycles
// frags / bytes_admitted: AW handshakes and their bytes after the burst splitter (what leaves the
// unit); bytes_charged: what the budget counter subtracted (it stops at 0, so an AW admitted on
// the last credit is not charged in full); budget_left: counter value at the end of the period;
// isolated_cycles: cycles with the budget spent. Times in cycles from the rising edge of
// realm_probe_en. A file is written only for units whose IMTU ran during the test.

bit          realm_probe_en;
int unsigned realm_probe_test;

for (genvar c = 0; c < NumClusters; c++) begin : gen_realm_probe_cl
  for (genvar j = 0; j < fpga_picobello_pkg::NumCores; j++) begin : gen_realm_probe_core
    initial begin : p_realm_probe
      automatic int          fd;
      automatic int unsigned t, t_start, period, frags, isolated;
      automatic longint unsigned bytes_adm, bytes_chg;
      automatic string       dir, path, rows [$];
      forever begin
        @(posedge realm_probe_en);
        rows.delete();
        t = 0; t_start = 0; period = 0; frags = 0; isolated = 0; bytes_adm = 0; bytes_chg = 0;
        while (realm_probe_en) begin
          @(posedge clk);
          t++;
          if (dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.aw_happening) begin
            frags++;
            bytes_adm += dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.aw_bytes;
          end
          if (dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.budget_en)
            bytes_chg += dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.bytes_spent;
          if (dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.budget_spent_o)
            isolated++;
          // period over: the counter reloads on the next edge
          if (dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.enable_i &&
              dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.period_left_o == 0) begin
            rows.push_back($sformatf("%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d", period, t_start, t, frags, bytes_adm,
              bytes_chg, dut.gen_clusters[c].i_cluster_rt_tile.i_axi_rt_unit_wide.gen_rt_units[j].i_axi_rt_unit.gen_regions[0].i_ax_rt_unit_counter_write.budget_left_o,
              isolated));
            period++; t_start = t; frags = 0; isolated = 0; bytes_adm = 0; bytes_chg = 0;
          end
        end
        if (rows.size() != 0 && $value$plusargs("VSIM_LOG=%s", dir)) begin
          $sformat(path, "%s/test%0d_realm_periods_cl_%0d_core_%0d.txt", dir, realm_probe_test, c, j);
          fd = $fopen(path, "w");
          $fwrite(fd, "# floomodel-trace: realm_periods/1\n");
          $fwrite(fd, "period, t_start, t_end, frags, bytes_admitted, bytes_charged, budget_left, isolated_cycles\n");
          foreach (rows[i]) $fwrite(fd, "%s\n", rows[i]);
          $fclose(fd);
        end
      end
    end
  end
end
