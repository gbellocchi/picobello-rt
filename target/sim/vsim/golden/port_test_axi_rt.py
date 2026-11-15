#!/usr/bin/env python3
# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Install the golden instrumentation in a picobello-rt `test/axi-rt` checkout (plan step 6.5).

    python port_test_axi_rt.py <test/axi-rt checkout>

The test/axi-rt tree renamed the testbench and tiles (tb_picobello_dse, picobello_dse_top,
traffic_gen_tile). This script writes, without touching tracked files:
  target/sim/include/tb_noc_link_tracer.svh, tb_axi_realm_probe.svh   hierarchy renamed
  target/sim/src/tb/tb_picobello_dse_golden.sv   tb_picobello_dse.sv (same module name) plus
      the tracer and probe, the plusargs (+FL_C ... +REG_I) and the FLOOMODEL_GOLDEN /
      FLOOMODEL_FLOWS scenario selection; no worst-case mode (+WC=1 is rejected)
and prints the Bender.yml change that selects it with the `golden` target. Scenarios come from
`floomodel export picobello` flow lists, since the scenario blocks of this tree differ from the
backup tree's.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..")


def sub1(s, old, new):
    assert old in s, f"anchor not found: {old[:60]!r}"
    return s.replace(old, new, 1)


def port_includes(root):
    for name in ("tb_noc_link_tracer.svh", "tb_axi_realm_probe.svh"):
        s = open(os.path.join(SRC, "include", name)).read().replace("i_cluster_rt_tile", "i_traffic_gen_tile").replace(
            "fpga_picobello_pkg::NumCores", "picobello_pkg::NumManagers")
        open(os.path.join(root, "target/sim/include", name), "w").write(s)


def port_tb(root):
    s = open(os.path.join(root, "target/sim/src/tb/tb_picobello_dse.sv")).read()
    s = sub1(s, "`define SAVE_BURST_TIMESTAMPS\n",
             "`define SAVE_BURST_TIMESTAMPS\n`define TRACE_NOC_LINKS // floomodel golden: link trace\n"
             "`define PROBE_AXI_REALM // floomodel golden: AXI-REALM period probe\n")
    m = re.search(r"// Traffic flow setup\n(.*?)\n\n", s, flags=re.S)
    s = s[:m.start()] + "// Traffic flow setup (with FLOOMODEL_GOLDEN from the command line)\n`ifndef FLOOMODEL_GOLDEN\n" \
        + m.group(1) + "\n`endif\n\n" + s[m.end():]
    s = re.sub(r"localparam bit (Critical|Interf)BudgetPeriodActive(\s*)= (1'b[01]);",
               r"bit \1BudgetPeriodActive\2= \3; // +REG_x", s)
    s = sub1(s, "  `ifdef INTER_FLOW_1H_ENDPOINT",
             "  `ifdef FLOOMODEL_FLOWS\n    `include \"floomodel_flows.svh\"\n  `endif\n\n  `ifdef INTER_FLOW_1H_ENDPOINT")
    task = '''`ifdef TRACE_NOC_LINKS
  `include "tb_noc_link_tracer.svh"
`endif
`ifdef PROBE_AXI_REALM
  `include "tb_axi_realm_probe.svh"
`endif

  // floomodel golden runs: sweep bounds from plusargs (each sets Min and Max of its sweep)
  task automatic floomodel_plusargs();
    int v;
    if ($value$plusargs("FL_C=%d", v))     begin CriticalBurstLengthMin = v; CriticalBurstLengthMax = v; end
    if ($value$plusargs("BUDGET_C=%d", v)) begin CriticalBudgetMin = v;      CriticalBudgetMax = v;      end
    if ($value$plusargs("PERIOD_C=%d", v)) begin CriticalPeriodMin = v;      CriticalPeriodMax = v;      end
    if ($value$plusargs("FL_I=%d", v))     begin InterfBurstLengthMin = v;   InterfBurstLengthMax = v;   end
    if ($value$plusargs("BUDGET_I=%d", v)) begin InterfBudgetMin = v;        InterfBudgetMax = v;        end
    if ($value$plusargs("PERIOD_I=%d", v)) begin InterfPeriodMin = v;        InterfPeriodMax = v;        end
    if ($value$plusargs("REG_C=%d", v))    CriticalBudgetPeriodActive = v[0];
    if ($value$plusargs("REG_I=%d", v))    InterfBudgetPeriodActive = v[0];
    if ($value$plusargs("WC=%d", v) && v != 0) $fatal(1, "worst-case mode not ported to tb_picobello_dse");
  endtask

  // TB execution //'''
    s = sub1(s, "  // TB execution //", task)
    i = s.index("  initial begin", s.index("  // TB execution //"))
    s = s[:i] + "  initial begin\n    floomodel_plusargs();" + s[i + len("  initial begin"):]
    s = sub1(s, "t_total.t0 = tb_timer_cnt_value;\n",
             "t_total.t0 = tb_timer_cnt_value;\n`ifdef TRACE_NOC_LINKS\n              noc_trace_test = NTest;\n"
             "              noc_trace_t0_timer = tb_timer_cnt_value;\n              noc_trace_en = 1'b1;\n`endif\n"
             "`ifdef PROBE_AXI_REALM\n              realm_probe_test = NTest;\n              realm_probe_en = 1'b1;\n`endif\n")
    s = sub1(s, "t_total.t1 = tb_timer_cnt_value;\n",
             "t_total.t1 = tb_timer_cnt_value;\n`ifdef TRACE_NOC_LINKS\n              noc_trace_en = 1'b0;\n`endif\n"
             "`ifdef PROBE_AXI_REALM\n              realm_probe_en = 1'b0;\n`endif\n")
    open(os.path.join(root, "target/sim/src/tb/tb_picobello_dse_golden.sv"), "w").write(s)


BENDER = """      # floomodel golden testbench (same module name), selected by the `golden` target
      - target: not(golden)
        files:
          - target/sim/src/tb/tb_picobello_dse.sv
      - target: golden
        files:
          - target/sim/src/tb/tb_picobello_dse_golden.sv
"""


def port_bender(root):
    p = os.path.join(root, "Bender.yml")
    s = open(p).read()
    if "tb_picobello_dse_golden.sv" not in s:
        s = sub1(s, "      - target/sim/src/tb/tb_picobello_dse.sv\n", BENDER)
        open(p, "w").write(s)


if __name__ == "__main__":
    root = sys.argv[1]
    port_includes(root)
    port_tb(root)
    port_bender(root)
    print(f"installed in {root}")
