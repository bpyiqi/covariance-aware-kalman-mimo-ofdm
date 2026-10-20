# Data dictionary

## Main 50-packet data

`validation50_packet_level.csv` stores one row per method, payload condition, and physical packet. Important fields include `payloadSymbols`, `nCodeword`, `packetIndex`, `method`, `packetSeed`, shared packet hashes, `avgCsiNmse`, `preLdpcBer`, `postLdpcBer`, `codewordPassRate`, `goodputMbps`, `softEvm`, runtime, and causality/solver audit counters.

`validation50_summary.csv` and the `validation50_paper_table_*.csv` files are derived summaries of the packet-level table. They are not independent samples.

## Robustness data

`robustness_ab_packet_level.csv` stores the 360 receiver rows from 20 physical packets across the paired SNR and Doppler conditions. `experiment = A` denotes the SNR sweep, `experiment = B` the Doppler sweep, and `experiment = A+B` the shared 20 dB/200 Hz center condition. `packetId` is the physical-packet resampling unit.

The robustness `*_summary.csv`, `*_paired_statistics.csv`, `*_bootstrap_ci.csv`, and `*_pairing_hashes.csv` files are derived from that packet table and the manifest.

## Independent ablation data

`independent_seed_packet_results.csv` contains 100 rows: 20 physical packets × 5 methods. `packetIndex` pairs methods sharing the same channel, transmitted bits, noise realization, and receiver scenario. `independent_seed_paired_statistics_final.csv` contains the post-processed paired comparisons and bootstrap intervals.

## Figure source data

The four CSV files in `data/figure_source/` are frozen, verified plotting tables. They contain 39 plotting rows in total and explicitly identify figure, sweep, x-value, method, metric, packet count, payload, and source-recovery provenance.

