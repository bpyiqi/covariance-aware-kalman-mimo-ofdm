# Configuration records

The experiment-specific configurations are retained with their evidence files rather than rewritten into a new parameter file.

- `data/main_50_packets/validation50_frozen_method_manifest.txt`: formal 50-packet settings, seeds, method list, covariance settings, and source hashes.
- `data/snr_sweep/robustness_ab_manifest.txt`: frozen robustness protocol, 20 physical packets, seed, quality gates, and causality label.
- `data/independent_ablation/independent_seed_manifest.txt`: independent 20-packet paired ablation protocol, seed, source hashes, and physical-packet resampling unit.

No parameter was tuned or changed during release assembly.

