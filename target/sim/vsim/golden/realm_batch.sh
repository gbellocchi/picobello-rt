#!/bin/bash
# Golden worst-case runs and AXI-REALM budget/period runs (link trace + REALM probe + pre-REALM monitor).
T=$(cd "$(dirname "$0")" && pwd)
G=PREFIX=golden_wc,WC_SCENARIO=1
R=WC_SCENARIO=0
bash $T/drive.sh $G@1:32:2048 $G@1:base $G@2:base $G@2:32:2048 \
  $R,PREFIX=realm_b256_noc,INTERF_BUDGET=256@1:16:2048 $R,PREFIX=realm_b512_noc,INTERF_BUDGET=512@1:16:2048 \
  $R,PREFIX=realm_b1024_noc,INTERF_BUDGET=1024@1:16:2048 $R,PREFIX=realm_b2048_noc,INTERF_BUDGET=2048@1:16:2048 \
  $R,PREFIX=realm_b512_noc,INTERF_BUDGET=512@1:32:4096 $R,PREFIX=realm_b2048_noc,INTERF_BUDGET=2048@1:32:4096 \
  $R,PREFIX=realm_b4096_noc,INTERF_BUDGET=4096@1:256:16384
