#!/usr/bin/env python3
"""[WC_TIMEOUT=<cycles>] [WC_SCENARIO=0|1] [INTERF_BUDGET=<bytes>] set_cfg.py <tb.sv> <hops> base|<fl> <p>

Select `define INTER_FLOW_<h>H and set the sweep bounds of its block:
  base   : FL=256 for all, AXI-REALM budget/period off (unregulated)
  fl p   : same FL and period P on all nodes, critical credit = P x 16 B, interferer credit = FL x 16 B
"""
import os, re, sys

tb, h = sys.argv[1], int(sys.argv[2])
base = sys.argv[3] == "base"
fl, p = (256, 2048) if base else (int(sys.argv[3]), int(sys.argv[4]))
vals = dict(CriticalBurstLength=fl, CriticalBudget=p * 16, CriticalPeriod=p,
            InterfBurstLength=fl, InterfBudget=int(os.environ.get("INTERF_BUDGET", fl * 16)), InterfPeriod=p)
src = open(tb).read()

# exactly one inter-flow scenario define active
for k in (1, 2, 4, 8):
    src = re.sub(rf"^(//\s*)?`define INTER_FLOW_{k}H\b", ("" if k == h else "// ") + f"`define INTER_FLOW_{k}H",
                 src, count=1, flags=re.M)

# sweep bounds inside the `ifdef INTER_FLOW_<h>H block
m = re.search(rf"`ifdef INTER_FLOW_{h}H\n(.*?)\n\s*`endif", src, flags=re.S)
blk, n = m.group(1), 0
for name, v in vals.items():
    blk, k = re.subn(rf"(int {name}(Min|Max) = )32'd\d+;", rf"\g<1>32'd{v};", blk)
    n += k
assert n == 12, f"replaced {n} values, expected 12"
src = src[:m.start(1)] + blk + src[m.end(1):]

# regulation on/off
for who in ("Critical", "Interf"):
    src, k = re.subn(rf"((?:localparam )?bit {who}BudgetPeriodActive\s*= )1'b[01];", rf"\g<1>1'b{0 if base else 1};", src)
    assert k == 1
# worst-case timeout (clock cycles, 0 = wait for the unfair critical task to terminate)
import os
src, k = re.subn(r"((?:localparam )?int unsigned WorstCaseTimeout\s*= )\d+;", rf"\g<1>{int(os.environ.get('WC_TIMEOUT', 0))};", src)
assert k == 1
# worst-case scenario on/off (WC_SCENARIO=0: all flows run their finite workload, as the RTL sweeps)
src, k = re.subn(r"((?:localparam )?bit\s+WorstCaseScenario\s*= )1'b[01];", rf"\g<1>1'b{int(os.environ.get('WC_SCENARIO', 1))};", src)
assert k == 1
open(tb, "w").write(src)
print(f"{tb}: INTER_FLOW_{h}H, " + ("unregulated FL=256" if base else f"FL={fl} P={p}"))
