# Covariance-Aware Data-Aided Kalman Channel Tracking Using Local LS Observations in Time-Varying MIMO-OFDM Systems

This repository contains the selected, provenance-tracked research data, MATLAB source closure, analysis files, and publication figures supporting the C1 Physical Communication study.

The method uses local MIMO-LS pseudo-observations from reliability-screened data symbols. Their observation covariance combines the candidate Gram geometry with a residual-derived scale, and the resulting covariance-aware observation is used in a data-aided Kalman channel-tracking update.

## Scope and evidence status

The repository contains:

- the frozen 50-physical-packet main results for payloads 169 and 507;
- the frozen 20-packet SNR/Doppler robustness experiment for payload 169;
- the independent 20-packet paired ablation experiment at SNR = 20 dB, maximum Doppler = 200 Hz, and payload = 169;
- source CSV files for Figs. 2–5 and the accepted PDF figures Figs. 1–5;
- MATLAB source and diagnostic code used by the C1 clean project.

The formal 50-packet result is preserved as frozen evidence. Its manifest records the historical source hashes, and the recovered historical snapshot is included under `provenance/frozen_source_snapshot_20260721/`. The current clean source is behaviorally audited but the complete original timestamped execution archive is not available; therefore this repository does **not** claim byte-for-byte end-to-end reproducibility of the original 50-packet execution.

The repository is intended for evidence inspection, figure regeneration, statistical review, and controlled continuation of the C1 analysis. A fresh large-scale channel simulation is not run by the release package.

## Repository layout

```text
README.md
CITATION.cff
startup_C1.m
Audit_ThreeLayer_Base_Oracle_Proposed.m
Run_PhysicalCom_Robustness_AB_v1.m
src/                              MATLAB +ofdm package support
audit_three_layer_helpers/         tracking, detector, covariance, and audit helpers
experiments/                        independent-seed experiment framework
code/plotting/                      fixed-input Fig. 2–Fig. 5 plotting entry
data/main_50_packets/              frozen formal 50-packet data and manifests
data/snr_sweep/                     frozen robustness A/B data for SNR views
data/doppler_sweep/                 same paired robustness dataset for Doppler views
data/independent_ablation/          independent 20-packet ablation data
data/figure_source/                 verified CSV data for Figs. 2–5
figures/                            publication PDF figures only
configs/                            configuration notes
docs/                               setup, data dictionary, provenance, and audit notes
provenance/                         source snapshots, comparison evidence, and hashes
tests/                              non-destructive checks and mathematical self-tests
SHA256SUMS.txt                     release-file SHA256 manifest
```

The root-level `src` and `audit_three_layer_helpers` paths are intentional: they preserve MATLAB package and relative-path semantics from the clean project. They are the runtime code closure, not a copy of the complete historical project.

## System configuration

- MATLAB: R2024a, version `24.1.0.2537033` in the frozen manifests.
- Core model: 2×2 MIMO-OFDM, 64-point FFT, 16-sample cyclic prefix, 20 MHz sampling rate, 16-QAM.
- Payloads in the formal validation: 169 and 507 OFDM symbols.
- Robustness payload: 169 OFDM symbols.
- LDPC: DVB-S2 half-rate configuration through MATLAB Communications Toolbox functions `dvbs2ldpc`, `ldpcEncoderConfig`, `ldpcDecoderConfig`, `ldpcEncode`, and `ldpcDecode`.
- Additional dependency: MATLAB Communications Toolbox for CRC and DVB-S2 LDPC support.
- No GPU-specific code is required by the stored analysis and smoke-test workflows.

The frozen protocols use the seeds and settings recorded in the manifests under `data/*/` and `provenance/`.

## Reproduction and analysis

Start a fresh MATLAB session in the repository root:

```matlab
cd('path/to/c1_github_release');
startup_C1;
```

Run the non-destructive path and smoke checks:

```matlab
run_clean_project_tests;
audit_quick_math_tests;
```

Regenerate Figs. 2–5 from the verified CSVs without channel simulation:

```matlab
addpath(fullfile(pwd,'code','plotting'));
plot_C1_Fig2_to_Fig5_Final(pwd, fullfile(pwd,'figures'), true);
```

The plotting entry reads only `data/figure_source/figure2_nmse_snr.csv`, `figure3_nmse_doppler.csv`, `figure4_preldpc_ber_snr.csv`, and `figure5_preldpc_ber_doppler.csv`. It does not read the formal 50-packet or independent-ablation tables as substitutes.

The stored independent-seed runner is documented in `docs/reproduction_guide.md`. It is retained as an experiment framework; executing it would be a new simulation and is not part of this release validation.

## Data interpretation

- NMSE is the per-physical-packet channel-error energy ratio followed by an arithmetic mean across physical packets.
- BER in the supplied main and robustness tables is explicitly **Pre-LDPC BER**.
- `postLdpcBer` is not used as a primary paper metric and may be unavailable in the frozen formal evidence.
- Robustness results are labeled `blockwise_calibrated_not_strict_symbol_causal` in the manifest.
- The simulation LTF initial estimate is a noisy estimate constructed from the true initial channel and noise model, not a hardware-captured LTF.
- The formal Proposed path has `NIS=false` in the frozen manifest.

See `docs/data_dictionary.md` for field definitions and `docs/provenance.md` for dataset-to-source mapping.

## Citation

The repository citation metadata is a draft because author names, affiliations, and the final public repository URL have not been supplied in the project files. Complete `CITATION.cff` before making the repository public or linking it from a paper.

## Contact and rights

No personal contact address, author identity, or license has been inferred or added. Confirm the corresponding-author contact and the copyright/license status of the MATLAB code and generated data before public release. Third-party MATLAB toolbox functions are dependencies and are not redistributed here.

