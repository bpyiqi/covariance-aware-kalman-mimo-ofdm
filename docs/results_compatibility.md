# Results Compatibility Assessment

## Current C1 compatibility rules

An artifact is directly reusable only when its method branch, physical packet pairing, payload/LDPC mapping, metric denominator, seed/configuration and source version are all traceable. Existing figures are not treated as primary data; their generating CSV and script must be identified.

## Compatibility conclusions

The robustness A/B outputs are the cleanest directly reusable secondary evidence. Their manifest states 360 receiver runs, 20 physical packet IDs, all-finite/all-PSD gates, zero solver failures, zero padding DA uses, zero same-symbol feedback and the blockwise-calibrated causality label. The current figure script reads `robustness_ab_summary.csv` directly and has PDF text QA JSON files.

The formal validation50 result is numerically consistent with the C1 table and prior audit, but its frozen manifest records hashes for an earlier main entry and estimator. Current hashes were recomputed during this review. This is a reproducibility-binding issue, not evidence that the table is numerically false. Until the exact historical source snapshot is recovered or an equivalence diff is documented, the table is `EXISTS_UNVERIFIED` under the requested strict rule.

The legacy long-payload/video assets are incompatible and must not be merged with C1. Their method names include `ReliableDataKalman`, `AdaptiveKalman`, `EMKalman`, `DataKalmanNoGram` and `DataKalmanNoGate`, but the receiver and metric pipeline are different.

The C1 manuscript reports NMSE and Pre-LDPC BER as its primary quantitative indicators. It does not need a post-LDPC BER claim; the NaN field must remain disclosed in internal evidence and omitted from the primary table.
