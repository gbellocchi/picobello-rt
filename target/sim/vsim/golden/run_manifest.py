#!/usr/bin/env python3
# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Run the RTL simulations of a floomodel golden manifest in a picobello-rt checkout.

    cd <picobello-rt> && source iis-env.sh
    python <floomodel>/rtl/picobello-rt/tools/run_manifest.py <manifest.yml> [--only GLOB] [--dry-run]

Needs the golden testbench copy (src/tb_picobello_fpga_fair_wc.sv of this directory, plusargs and
FLOOMODEL_GOLDEN scenario defines) and the `golden` bender target (bender_golden_target.patch).

Per compile group (topology + scenario define or exported flow list) it compiles once into
runs/floomodel_<group>/work and optimizes the testbench once (vopt); every manifest entry then runs
from that library with its own run directory runs/<name>/ (log/, run.log, run_meta.json) and its
plusargs. At most --max-runs simulations at a time plus one compile (default 6: 7 Questa processes
of the user, 8-license cap). Waveforms are never written.

Manifest:
    set: <golden set name>
    runs:
      - name: golden_noc_2h_fl32_p2048        # run directory name (also the case name)
        topology: cfg/rt_inter_flow_2h.yml    # floogen file, relative to the checkout
        traffic: target/sim/src/traffic/rt_inter_flow_noc_2h.yml
        define: INTER_FLOW_2H                 # scenario block of the testbench, or
        flows_svh: <path>                     # a flow list from `floomodel export picobello`
        plusargs: {FL_C: 32, BUDGET_C: 32768, PERIOD_C: 2048, FL_I: 32, BUDGET_I: 512, PERIOD_I: 2048,
                   WC: 0, WC_TIMEOUT: 0, REG_C: 1, REG_I: 1}
"""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time

import yaml

ARGS = None

SIM_TARGS = "-t simulation -t test -t idma_test -t floo_test -t golden -D FLOOMODEL_GOLDEN"
TB = "tb_picobello_fpga_fair"  # --tb-module (test/axi-rt: tb_picobello_dse)
TB_SRC = "target/sim/src/tb_picobello_fpga_fair_wc.sv"  # --tb-src (test/axi-rt: target/sim/src/tb/tb_picobello_dse_golden.sv)
VSIM_FLAGS = ["-suppress", "3009", "-suppress", "8386", "-suppress", "13314", "-quiet", "-64"]


def sh(cmd, log=None, cwd=None):
    out = open(log, "w") if log else subprocess.DEVNULL
    return subprocess.run(cmd, shell=isinstance(cmd, str), cwd=cwd, stdout=out, stderr=subprocess.STDOUT).returncode


def n_vsimk():
    r = subprocess.run(["pgrep", "-u", os.environ.get("USER", ""), "-c", "vsimk"], capture_output=True, text=True)
    return int(r.stdout.strip() or 0)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest() if os.path.exists(path) else None


def git_info(root):
    def g(*a):
        r = subprocess.run(["git", "-C", root, *a], capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else None
    diff = g("diff", "HEAD")
    return dict(commit=g("rev-parse", "HEAD"), branch=g("rev-parse", "--abbrev-ref", "HEAD"),
                diff_sha256=hashlib.sha256(diff.encode()).hexdigest() if diff else None)


def deps(root):
    lock = yaml.safe_load(open(os.path.join(root, "Bender.lock")))["packages"]
    out = {}
    for name in ("floo_noc", "axi_rt"):
        p = lock.get(name, {})
        out[name] = dict(revision=p.get("revision"), version=p.get("version"))
        co = subprocess.run(f"ls -d {root}/.bender/git/checkouts/{name}-*", shell=True, capture_output=True, text=True)
        for d in co.stdout.split():
            diff = subprocess.run(["git", "-C", d, "diff"], capture_output=True, text=True).stdout
            out[name]["dirty_sha256"] = hashlib.sha256(diff.encode()).hexdigest() if diff else None
    return out


def group_key(e):
    tag = e.get("define") or ("flows_" + hashlib.sha256(open(e["flows_svh"], "rb").read()).hexdigest()[:8])
    topo = os.path.splitext(os.path.basename(e["topology"]))[0]
    return f"floomodel_{topo}_{tag}".lower()


def compile_group(root, key, e, logdir):
    runs = os.path.join(root, "target/sim/vsim/runs")
    shutil.rmtree(os.path.join(runs, key), ignore_errors=True)
    defines = SIM_TARGS + (f" -D {e['define']}" if e.get("define") else " -D FLOOMODEL_FLOWS")
    if e.get("flows_svh"):
        shutil.copy(e["flows_svh"], os.path.join(root, "target/sim/include/floomodel_flows.svh"))
    if sh(f"make floo-clean floo-hw-all FLOO_CFG={e['topology']}", os.path.join(logdir, f"floo_{key}.log"), root):
        return False
    log = os.path.join(logdir, f"compile_{key}.log")
    rc = sh(f'make vsim-compile FLOO_CFG={e["topology"]} VSIM_NAME={key} SIM_TARGS="{defines}"', log, root)
    if rc or re.search(r"Errors: [1-9]", open(log).read()):
        return False
    work = os.path.join(runs, key, "work")
    vsim = os.environ.get("VSIM", "vsim").split()
    vopt = vsim[:-1] + ["vopt"]
    rc = sh(vopt + ["-64", "-work", work, "+acc", ARGS.tb_module, "-o", "tb_golden_opt"], os.path.join(logdir, f"vopt_{key}.log"),
            os.path.join(runs, key))
    return rc == 0


def jobs(root, e, logdir):
    """gen_jobs.py output for the traffic file, shared by every run with that traffic."""
    name = os.path.splitext(os.path.basename(e["traffic"]))[0]
    path = os.path.join(root, e["traffic"])
    out = os.path.join(root, "target/sim/vsim/runs/jobs", f"floomodel_{name}_{sha(path)[:8]}")
    if not os.path.isdir(out):
        os.makedirs(out)
        bender = os.environ.get("BENDER", f"bender -d {root}").split()
        floo = subprocess.run(bender + ["path", "floo_noc"], capture_output=True, text=True, cwd=root).stdout.strip()
        py = os.environ.get("BASE_PYTHON", sys.executable)
        rc = sh([py, os.path.join(floo, "util/gen_jobs.py"), "--out_dir", out, "--tb", "import_traffic_cfg",
                 "--traffic_cfg", os.path.join(root, e["traffic"]), "--floonoc_cfg", os.path.join(root, e["topology"])],
                os.path.join(logdir, f"jobs_{name}.log"), root)
        if rc:
            raise RuntimeError(f"gen_jobs failed for {e['traffic']}")
    return out + "/"


def launch(root, key, e, job_dir, meta):
    runs = os.path.join(root, "target/sim/vsim/runs")
    rd = os.path.join(runs, e["name"])
    shutil.rmtree(rd, ignore_errors=True)
    os.makedirs(os.path.join(rd, "log"))
    shutil.copy(os.path.join(root, ARGS.tb_src), os.path.join(rd, "tb_snapshot.sv"))
    vsim = os.environ.get("VSIM", "vsim").split()
    plus = [f"+{k}={v}" for k, v in (e.get("plusargs") or {}).items()]
    cmd = vsim + ["-c"] + VSIM_FLAGS + ["-lib", os.path.join(runs, key, "work"), f"+VSIM_LOG={rd}/log",
                                        "+JOB_NAME=traffic", f"+JOB_DIR={job_dir}"] + plus + \
        ["tb_golden_opt", "-do", "run -a; quit"]
    meta = dict(meta, name=e["name"], topology=e["topology"], traffic=e["traffic"], define=e.get("define"),
                flows_svh=e.get("flows_svh"), plusargs=e.get("plusargs") or {}, compiled=key, case=e.get("case"),
                start=datetime.datetime.now().isoformat(timespec="seconds"))
    log = open(os.path.join(rd, "run.log"), "w")
    p = subprocess.Popen(cmd, cwd=rd, stdout=log, stderr=subprocess.STDOUT)
    return p, meta, rd, time.time()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--root", default=os.getcwd(), help="picobello-rt checkout")
    ap.add_argument("--only", default="*")
    ap.add_argument("--max-runs", type=int, default=6)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--tb-module", default=TB)
    ap.add_argument("--tb-src", default=TB_SRC)
    ap.add_argument("--set", help="override the manifest's set name in run_meta.json")
    global ARGS
    a = ARGS = ap.parse_args()
    m = yaml.safe_load(open(a.manifest))
    entries = [e for e in m["runs"] if fnmatch.fnmatch(e["name"], a.only)]
    logdir = os.path.join(a.root, "target/sim/vsim/runs/floomodel_logs")
    os.makedirs(logdir, exist_ok=True)
    groups = {}
    for e in entries:
        groups.setdefault(group_key(e), []).append(e)
    if a.dry_run:
        for k, es in groups.items():
            print(k, [e["name"] for e in es])
        return 0
    base = dict(set=a.set or m.get("set"), source="picobello-rt", root=a.root, host=socket.gethostname(),
                tb=a.tb_src, tb_sha256=sha(os.path.join(a.root, a.tb_src)),
                git=git_info(a.root), deps=deps(a.root), simulator=os.environ.get("VSIM"))
    running, failed = [], []

    def reap(block):
        while running and (block or any(p.poll() is not None for p, *_ in running)):
            for item in list(running):
                p, meta, rd, t0 = item
                if p.poll() is None:
                    continue
                txt = open(os.path.join(rd, "run.log"), errors="replace").read()
                bad = p.returncode != 0 or "** Fatal" in txt or re.search(r"# Errors: [1-9]", txt)
                meta.update(end=datetime.datetime.now().isoformat(timespec="seconds"), sim_wall_s=round(time.time() - t0, 1),
                            returncode=p.returncode, ok=not bad)
                if bad:
                    failed.append(meta["name"])
                json.dump(meta, open(os.path.join(rd, "run_meta.json"), "w"), indent=1)
                print(f"{meta['end']} done {meta['name']} {'ok' if not bad else 'FAILED'} ({meta['sim_wall_s']} s)", flush=True)
                running.remove(item)
            if block and running:
                time.sleep(10)
            elif running:
                break

    for key, es in groups.items():
        while n_vsimk() >= a.max_runs + 1:
            reap(False)
            time.sleep(15)
        print(f"compile {key}", flush=True)
        if not compile_group(a.root, key, es[0], logdir):
            print(f"compile FAILED {key} (logs in {logdir})", flush=True)
            failed += [e["name"] for e in es]
            continue
        for e in es:
            while n_vsimk() >= a.max_runs:
                reap(False)
                time.sleep(15)
            running.append(launch(a.root, key, e, jobs(a.root, e, logdir), base))
            print(f"{datetime.datetime.now():%H:%M:%S} start {e['name']}", flush=True)
            time.sleep(5)
    reap(True)
    if failed:
        print("failed:", " ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
