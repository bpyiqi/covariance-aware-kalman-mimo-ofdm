# Final 20 packet statistical review

## Review scope

This review used the completed packet CSV, paired-statistics CSV, independent-run manifest, and the unchanged MATLAB metric/bootstrap implementations. No packet simulation, formal 50-packet run, or SNR scan was rerun.

## Integrity gates

| Check | Result | Evidence |
|---|---|---|
| Physical packets | PASS: 20 unique packet indices | packet CSV |
| Method rows | PASS: 5 methods × 20 = 100 rows | packet CSV |
| Pairing hashes | PASS: H, bits, QAM, padding, unit noise and received grid are identical within each packet | packet CSV |
| Cross-packet independence | PASS: 20 unique channel and received-grid hashes | packet CSV |
| Configuration | PASS: SNR 20 dB, Doppler 200 Hz, payload 169, one codeword, seed 2026100901 | manifest/CSV |
| Finite metrics | PASS: NMSE, Pre-LDPC BER and EVM have zero NaN/Inf rows | packet CSV |
| Bootstrap | PASS: 10,000 replicates, physical packet resampling, deterministic MATLAB `rng` stream | runner and `auditPairedBootstrapCi.m` |

The packet CSV metadata now uses the valid bootstrap seed `2026100902`. This metadata correction did not change packet-level numerical columns.

## Metric definitions

The implementation computes CSI NMSE on the configured active subcarriers. Pre-LDPC BER is the hard decision `LLR < 0` compared with coded bits on the valid resource-element mask; padding is excluded. Soft EVM is computed from the soft detector symbols against the transmitted QAM symbols. Post-LDPC BER is not present in this receiver output and must remain unavailable rather than being reported as zero.

## Paired bootstrap review

For every comparison, the code sorts both method vectors by `packetIndex`, forms one delta per physical packet, resamples those 20 deltas with replacement, and takes the deterministic 2.5th and 97.5th percentiles of 10,000 bootstrap means. Independent recomputation of the point estimates from the original 18-row statistics file agrees with the stored values to at most `4.1e-9`, attributable to CSV rounding. A final read-only audit file adds the three direct Proposed-versus-Fixed rows, giving 21 rows total; all intervals are ordered and contain their point estimates.

## Main comparisons

| Comparison and metric | Mean paired delta | 95% CI | Interpretation |
|---|---:|---:|---|
| Fixed − Base NMSE | -0.008793 | [-0.010622, -0.007053] | supports lower NMSE |
| Fixed − Base Pre-LDPC BER | -0.012455 | [-0.016320, -0.008704] | supports lower BER |
| Proposed − Base NMSE | -0.011699 | [-0.014144, -0.009452] | supports lower NMSE |
| Proposed − Base Pre-LDPC BER | -0.014803 | [-0.019399, -0.010327] | supports lower BER |
| Proposed − Fixed NMSE | -0.002906 | [-0.003569, -0.002330] | supports lower NMSE |
| Proposed − Fixed Pre-LDPC BER | -0.002348 | [-0.003857, -0.000955] | supports lower BER |

The stored file uses `comparison − reference` orientation. Thus the rows labeled `Base → Proposed` contain `Proposed − Base`, the rows labeled `Proposed → Fixed` contain `Fixed − Proposed`, and the positive rows labeled `Proposed → Gram/Residual` contain the ablation minus Proposed difference. The three Proposed-versus-Fixed rows were added by read-only post-processing from the same packet CSV in `independent_seed_paired_statistics_final.csv`.

## Mechanism comparisons

| Comparison | NMSE delta, 95% CI | Pre-LDPC BER delta, 95% CI | Soft EVM delta, 95% CI |
|---|---|---|---|
| Gram-only − Proposed | +0.002935 [0.001549, 0.004604] | +0.004292 [0.002194, 0.006858] | +0.022057 [0.013985, 0.030748] |
| Residual-only − Proposed | +0.004822 [0.003730, 0.006070] | +0.007104 [0.004346, 0.010168] | +0.035632 [0.028596, 0.042971] |

All six mechanism-specific intervals exclude zero. This supports the claim that the full covariance-aware construction outperformed each strict ablation under this independent center condition. It does not establish universal superiority over all channels or all SNRs.

## Influence of high-error packets

All 20 packet deltas favor Fixed over Base and Proposed over Base for NMSE and Pre-LDPC BER. For Proposed versus Gram-only, all 20 NMSE and BER deltas favor Proposed; EVM has 19 favorable packets and one opposite packet. The largest three absolute deltas account for approximately 52.6% of the Gram-only NMSE absolute delta and 51.3% of its BER absolute delta. However, after removing the most extreme packet, the remaining 18-packet mean differences remain positive: Gram-only minus Proposed is 0.000204 to 0.010793 per-packet range for NMSE and 0.000062 to 0.013025 for BER. The result is therefore not a single-packet artifact, although the small sample size warrants restrained wording.

## Statistical conclusion

The independent 20-packet data provide consistent paired support for the Full Proposed method over Base, Fixed-R3, Gram-only and Residual-only for the reported NMSE and Pre-LDPC BER measures. Goodput is not included in these significance claims; no independent Goodput confidence interval was requested or generated. No result supports a claim of statistically significant throughput improvement.
