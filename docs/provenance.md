# Provenance and release boundaries

All release files were copied from `D:\matlabfile\C1_PhysicalCommunication_Clean` after read-only inventory. The original clean project and historical project were not modified by release assembly, and no channel simulation was run.

The formal 50-packet manifest is `data/main_50_packets/validation50_frozen_method_manifest.txt`. It records the historical hashes for the entry point, covariance-aware validation functions, OJCD dependency, seed, MATLAB version, payloads, and covariance settings. The recovered historical source snapshot is under `provenance/frozen_source_snapshot_20260721/`; source differences and behavioral evidence are under `provenance/source_comparisons/`.

The robustness manifest is `data/snr_sweep/robustness_ab_manifest.txt` and is duplicated in `data/doppler_sweep/` only as a view-specific copy of the same frozen A/B dataset. The independent ablation manifest is `data/independent_ablation/independent_seed_manifest.txt`.

The release does not contain the Chinese or English manuscript Word files, unpublished PDF manuscripts, cover letters, credentials, tokens, SSH keys, or unrelated C2/video/UAV research lines. The publication figures are supplied as separate PDFs; the source data for Figs. 2–5 is supplied as CSV.

