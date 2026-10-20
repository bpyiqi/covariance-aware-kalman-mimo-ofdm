# Release selection and exclusions

## Included

- Frozen 50-packet main evidence: packet-level rows, summaries, paired statistics, bootstrap intervals, pairing hashes, runtime/RDA audits, manifests, and MAT containers for payloads 169 and 507.
- Frozen robustness A/B evidence: packet-level rows, SNR/Doppler summaries, paired statistics, bootstrap intervals, pairing hashes, quality gates, runtime audit, and manifests.
- Independent 20-packet ablation evidence: packet-level rows, final paired statistics, MAT containers, manifest, and the experiment framework.
- MATLAB source closure: the C1 entry points, `src/+ofdm`, covariance-aware tracking and diagnostic helpers, OJCD support, uncertainty mapping, tests, and the verified plotting entry.
- Publication figures as standalone PDFs and verified Fig. 2–Fig. 5 source CSVs.
- Source-binding snapshots and audit comparison files needed to interpret the frozen 50-packet result.

## Excluded

- Chinese and English manuscript Word/PDF files, MathType/OLE assets, cover letters, and author metadata.
- Historical video-link, UAV, FPGA/RTL, neural-network, and C2 research lines.
- Legacy estimator results that use incompatible receiver or metric schemas.
- Temporary QA images, duplicate historical figure directories, MATLAB cache files, and failed/intermediate outputs.
- Credentials, tokens, private keys, personal contact information, and local manuscript paths.

No excluded file was deleted from the clean project or the historical project.

