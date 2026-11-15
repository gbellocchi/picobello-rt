#!/bin/bash
# Traced RTL runs that form the golden set of runs/py_model_bw (see golden.py).
T=$(cd "$(dirname "$0")" && pwd)
PREFIX=golden_noc WC_SCENARIO=0 bash $T/drive.sh 2:base 4:base 8:base 1:32:2048 2:32:2048 4:32:2048 8:32:2048 1:16:8192 2:16:8192 4:16:8192 8:16:8192
PREFIX=golden_wc WC_SCENARIO=1 bash $T/drive.sh 1:base 2:base 1:32:2048 2:32:2048
