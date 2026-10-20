# GitHub release audit

## Current state

- Local release directory: `D:\matlabfile\C1_PhysicalCommunication_Clean\c1_github_release`
- Proposed repository: `c1-covariance-aware-kalman-mimo-ofdm`
- Intended owner: `bpyiqi` (authenticated GitHub profile observed during the read-only check)
- Repository URL: **PENDING PRIVATE-REPOSITORY CREATION**
- GitHub visibility: **NOT CREATED / NOT PUBLIC**
- GitHub CLI: unavailable on the current host (`gh` was not found).
- GitHub connector repository lookup: the proposed repository returned 404 before creation.

## Local package audit

- Release files: 331 hashed files plus `SHA256SUMS.txt` (332 files total).
- Release size before Git metadata: 17,088,797 bytes.
- Files at or above 100 MB: 0.
- Manuscript files included: none.
- Credentials or private-key pattern matches after sanitization: none.
- SHA256 manifest: `SHA256SUMS.txt`.
- Main packet CSV rows: 600, covering payloads 169 and 507 and six recorded methods.
- Robustness packet CSV rows: 360, covering the verified A/B SNR and Doppler views with 20 physical packets per condition-method group.
- Independent ablation packet CSV rows: 100, covering 20 packets × 5 methods.
- Publication figures: five standalone PDF files.

The selected release data were compared against their clean-project source files. The copied main packet CSV, robustness packet CSV, independent packet CSV, and all four Fig. 2–Fig. 5 source CSVs have matching SHA256 values.

## Dataset directories

- `data/main_50_packets/`: frozen formal 50-packet evidence for payloads 169 and 507.
- `data/snr_sweep/`: SNR view of the frozen A/B robustness dataset.
- `data/doppler_sweep/`: Doppler view of the same frozen A/B robustness dataset; no samples were duplicated as new physical packets.
- `data/independent_ablation/`: independent seed 20-packet Base/Fixed/Gram-only/Residual-only/Proposed evidence.
- `data/figure_source/`: verified source CSVs for Figs. 2–5.

## Reproducibility boundary

Figure regeneration and read-only statistical inspection are supported by the included files. The formal 50-packet data are complete as frozen evidence, but the historical manifest contains an estimator hash that differs from the current clean source; the recovered snapshot and comparison evidence are included. A byte-for-byte rerun of the original 50-packet execution is therefore **not claimed**. The release also does not claim that running the independent-seed runner reproduces the stored samples, because that would generate new packets.

## Code and dependencies

The MATLAB source closure is included at the repository root to preserve package and relative-path semantics. MATLAB R2024a and Communications Toolbox are required for the stored receiver and tests. Third-party toolbox functions are dependencies, not redistributed source.

## Rights and public-release gate

No open-source license has been added. Author ownership, third-party code rights, author names, corresponding-author contact, and the final public repository URL must be confirmed before changing visibility from Private or linking the repository in a manuscript.

## Data Availability statement draft

> The processed data underlying Figs. 2–5, the frozen packet-level results for the 50-packet main validation and the independent 20-packet ablation, the associated MATLAB analysis and plotting code, and the provenance manifests are available in the accompanying private GitHub repository during manuscript evaluation. A public repository record and persistent identifier will be supplied after author approval and release of the associated code and data. The formal 50-packet package includes the historical source-hash manifest and recovered source snapshot; because the original timestamped execution archive is incomplete, the repository is provided as a provenance-tracked evidence and analysis package rather than a claim of byte-for-byte rerun reproducibility.

This draft must be updated with the final repository URL, persistent identifier if obtained, author-approved access status, and any license before submission.

