#!/usr/bin/env python3
# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Disk hygiene of picobello-rt run directories (plan step 6.7).

    python clean_runs.py <runs dir> --golden <floomodel>/golden [--delete]

A run directory that has been ingested into a golden set (a case whose provenance names the run)
only needs log/, run.log, run_meta.json and tb_snapshot.sv. This script lists, per such run, what
can go: the compiled work library (work/), waveforms (*.wlf, *.vcd), transcripts of the GUI. Without
--delete it only reports (default); with --delete it removes them. Runs that are not in a golden set
are never touched.
"""
import argparse
import glob
import gzip
import json
import os
import shutil

KEEP = {"log", "run.log", "run_meta.json", "tb_snapshot.sv"}
DROP_GLOBS = ("work", "*.wlf", "*.vcd", "transcript", "vsim.dbg", "modelsim.ini", "compile.tcl")


def ingested_runs(golden):
    runs = set()
    for p in glob.glob(os.path.join(golden, "cases", "*", "*.json.gz")):
        with gzip.open(p, "rt") as f:
            runs.add(json.load(f)["provenance"]["run"])
    return runs


def size(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    return sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(path) for f in fs
               if not os.path.islink(os.path.join(d, f)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runs")
    ap.add_argument("--golden", required=True)
    ap.add_argument("--delete", action="store_true")
    a = ap.parse_args()
    known = ingested_runs(a.golden)
    total = 0
    for rd in sorted(glob.glob(os.path.join(a.runs, "*/"))):
        name = os.path.basename(rd.rstrip("/"))
        if name not in known:
            continue
        victims = [p for g in DROP_GLOBS for p in glob.glob(os.path.join(rd, g)) if os.path.basename(p) not in KEEP]
        sz = sum(size(p) for p in victims)
        if not victims:
            continue
        total += sz
        print(f"{'delete' if a.delete else 'would delete'} {sz / 1e9:7.2f} GB  {name}: "
              + ", ".join(os.path.basename(p) for p in victims))
        if a.delete:
            for p in victims:
                shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    print(f"{'freed' if a.delete else 'reclaimable'}: {total / 1e9:.1f} GB in ingested runs")


if __name__ == "__main__":
    main()
