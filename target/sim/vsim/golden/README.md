# Golden RTL runs for FlooModel

Instrumentation and scripts that produce the golden reference of
[floomodel](https://github.com/gbellocchi/floomodel) (copies there under `rtl/picobello-rt/`).

- `target/sim/src/tb_picobello_fpga_fair_wc.sv`: testbench copy (module `tb_picobello_fpga_fair`)
  with the worst-case scenario, the link tracer, the AXI-REALM probe, plusargs
  (`+FL_C +BUDGET_C +PERIOD_C +FL_I +BUDGET_I +PERIOD_I +WC +WC_TIMEOUT +REG_C +REG_I`) and
  `FLOOMODEL_GOLDEN` / `FLOOMODEL_FLOWS` scenario selection. Selected by the bender target `golden`.
- `target/sim/include/tb_noc_link_tracer.svh`, `tb_axi_realm_probe.svh`: the passive monitors.
- `drive.sh`, `set_cfg.py`, `*_batch.sh`: the driver of set picobello-rt-v1 (now compiles with
  `-t golden`, no edit of Bender.yml).
- `run_manifest.py`: manifest runner (one compile per topology, plusargs, at most 7 Questa processes).
- `port_test_axi_rt.py`: installs the instrumentation in a test/axi-rt checkout.
- `clean_runs.py`: removes work libraries and waveforms of runs already ingested into a golden set.

Procedure: floomodel `docs/golden/producing.md`.
