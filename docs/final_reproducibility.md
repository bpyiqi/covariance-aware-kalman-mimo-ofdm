# Final reproducibility status

## What is closed

- The exact historical estimator and OJCD blobs named by the frozen manifest were recovered and stored read-only.
- Current clean source hashes and frozen hashes are recorded without changing the frozen manifest.
- The ordinary estimator path is behaviorally equivalent on a deterministic packet for the tested methods.
- Direct OFDM, feature mapping, LS-covariance, Kalman, and detector dependencies were compared against the recovered historical tree where available.
- Strict Gram-only and Residual-only definitions were implemented in a separate round-3 directory; the one-packet numerical smoke passed.

## What remains open

- The 20-packet independent-seed experiment must be completed and its checkpoint, packet CSV, MAT, pairing checks, and bootstrap intervals reviewed.
- The new ablation code generated the complete 20-packet paired confidence intervals; the result files and source manifest are under `experiments/independent_seed_20261009/`.
- The frozen 50-packet source binding is now auditable by exact historical snapshot, but the original execution process still lacks a complete timestamped commit/execution archive.

The clean project itself has no dependency on old-project source code in its startup path. The historical snapshot is evidence, not a runtime dependency. The completed independent run used MATLAB version and final corrected source SHA256 records written to `independent_seed_manifest.txt`; because the packet phase preceded two post-processing-only fixes, the independent-run wrapper binding is explicitly `PARTIAL_POSTPROCESS_ONLY`.
