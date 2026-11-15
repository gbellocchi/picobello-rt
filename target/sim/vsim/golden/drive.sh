#!/bin/bash
# [PREFIX=wc_noc] [WC_SCENARIO=1] [WC_TIMEOUT=0] [INTERF_BUDGET=..] drive.sh <item>...
#   item = [VAR=val,VAR=val@]<h>:base | [VAR=val,...@]<h>:<fl>:<p>   (per-item overrides of the variables)
# Compiles the worst-case testbench copy for each item (sequentially, the generated NoC package and
# the TB source are shared) and runs it in the background without waveform logging.
# At most 7 Questa processes of this user at any time (6 runs + 1 compile).
set -u
T=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$T/../../../.." && pwd)
LOGS=$ROOT/target/sim/vsim/runs/golden_logs; mkdir -p $LOGS
TB=$ROOT/target/sim/src/tb_picobello_fpga_fair_wc.sv
cd $ROOT && source iis-env.sh > /dev/null

nrun() { pgrep -u "$USER" -c vsimk || true; }

D_ENV="PREFIX=${PREFIX:-} WC_SCENARIO=${WC_SCENARIO:-} WC_TIMEOUT=${WC_TIMEOUT:-} INTERF_BUDGET=${INTERF_BUDGET:-}"
for it in "$@"; do
  export $D_ENV; [ -z "$WC_TIMEOUT" ] && unset WC_TIMEOUT; [ -z "$INTERF_BUDGET" ] && unset INTERF_BUDGET
  [ -z "$WC_SCENARIO" ] && unset WC_SCENARIO; [ -z "$PREFIX" ] && unset PREFIX
  if [[ $it == *@* ]]; then export $(echo ${it%@*} | tr , ' '); it=${it#*@}; fi
  IFS=: read -r h a b <<< "$it"
  if [ "$a" = base ]; then N=${PREFIX:-wc_noc}_${h}h_baseline${WC_TIMEOUT:+_t$WC_TIMEOUT}; .venv/bin/python $T/set_cfg.py $TB $h base
  else N=${PREFIX:-wc_noc}_${h}h_fl${a}_p${b}; .venv/bin/python $T/set_cfg.py $TB $h $a $b; fi || exit 1
  while [ "$(nrun)" -ge 6 ]; do sleep 30; done
  make floo-clean floo-hw-all FLOO_CFG=cfg/rt_inter_flow_${h}h.yml > /dev/null 2>&1 || exit 1
  rm -rf target/sim/vsim/runs/$N
  # the golden testbench copy is selected by the `golden` bender target (no edit of Bender.yml)
  make vsim-compile FLOO_CFG=cfg/rt_inter_flow_${h}h.yml VSIM_NAME=$N \
    SIM_TARGS="-t simulation -t test -t idma_test -t floo_test -t golden" > $LOGS/compile_$N.log 2>&1
  rc=$?
  if [ $rc -ne 0 ] || grep -q "^# \*\* Error: .*tb_picobello" $LOGS/compile_$N.log; then echo "compile FAILED $N"; continue; fi
  cp $TB target/sim/vsim/runs/$N/tb_snapshot.sv
  echo "$(date +%T) start $N"
  ( make vsim-run-batch FLOO_CFG=cfg/rt_inter_flow_${h}h.yml VSIM_NAME=$N \
      JOB_DIR=$ROOT/target/sim/vsim/runs/jobs/noc_${h}h/ 'VSIM_COMMON_CMD=run -a;' \
      > target/sim/vsim/runs/$N/run.log 2>&1
    echo "$(date +%T) done $N rc=$?" ) &
  sleep 20
done
wait
