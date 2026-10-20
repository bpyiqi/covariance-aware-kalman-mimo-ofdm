# Reproduction and reuse guide

## Read-only result inspection

1. Open the relevant manifest in `data/main_50_packets/`, `data/snr_sweep/`, or `data/independent_ablation/`.
2. Verify the corresponding file hash in `SHA256SUMS.txt`.
3. Use the packet-level CSV as the primary numerical evidence and the summary tables only as derived views.
4. Treat physical packet IDs, not individual codewords, as the bootstrap unit.

## Figure regeneration

```matlab
cd('path/to/c1_github_release');
startup_C1;
addpath(fullfile(pwd,'code','plotting'));
plot_C1_Fig2_to_Fig5_Final(pwd, fullfile(pwd,'figures'), true);
```

The figure script reads only the four verified files in `data/figure_source/` and regenerates Fig. 2 (NMSE–SNR), Fig. 3 (NMSE–Doppler), Fig. 4 (Pre-LDPC BER–SNR), and Fig. 5 (Pre-LDPC BER–Doppler). Fig. 1 is distributed as the accepted vector PDF.

## Independent ablation runner

The runner is stored at `experiments/runC1IndependentSeed20.m`, with its estimator wrapper at `experiments/independent_seed_20261009/ablation/c1RunSingleEstimatorAblation.m`. The exact original command is preserved in `docs/reproduction_commands_original.md`. Running it creates new physical packets and is intentionally not performed by the release audit.

## Formal 50-packet run

The frozen 50-packet outputs are included for inspection. A fresh formal rerun is not claimed because the frozen execution lacks a complete timestamped source/execution archive even though the historical source snapshot and behavioral comparison evidence are included.

