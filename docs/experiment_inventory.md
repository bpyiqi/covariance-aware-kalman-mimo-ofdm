# Full Historical Experiment Inventory

## Scope and evidence rule

The project was searched across MATLAB sources, result directories, CSV/JSON/TXT reports, MAT metadata, figure-generation scripts, and the C1 manuscript. `.git`, audit bundles, and large binary payloads were not used as numerical evidence. MAT files were inspected with `whos -file`; arrays were not loaded for this inventory. The MAT field inventory is in `mat_inventory.csv`.

The manuscript was inspected locally during the audit but is intentionally excluded from this release. Its local path and document hash are not reproduced here.

Status meanings are the requested five classes. `EXISTS_UNVERIFIED` is used when an artifact is complete but its source/configuration binding is not exact; it is not equivalent to missing. The complete row-level inventory is `experiment_inventory.csv`.

## Findings by requested asset

| Area | Finding | Status |
|---|---|---|
| Formal Base/Fixed/Proposed | 50-packet-per-payload frozen result exists with packet rows, pairing hashes, bootstrap CIs, runtime and paper tables. | EXISTS_UNVERIFIED |
| Gram-only | No exact current-version pure Gram-only branch or result was found. | MISSING |
| Residual-only | `FixedRadius3LsCovOnlyCausal_EP` exists, but its `Rls` uses both residual variance and the Gram inverse. | PARTIAL |
| Full covariance-aware | Current 20-packet mechanism decomposition exists; the 50-packet formal result also exists with a source-hash caveat. | PARTIAL |
| Radius sensitivity | Current diagnostic includes FixedRadius1/2/3 and dynamic selection. | VERIFIED_COMPLETE |
| Gram threshold/rank | Rejection counters and one frozen threshold exist; no threshold sweep. | PARTIAL |
| NIS/decision inflation | A--G branch decomposition and NIS/RDA audits exist. | VERIFIED_COMPLETE |
| Independent seeds | Current-method SNR scans exist at seeds 20260724 and 20260725, but not a formal center-condition replicate. | PARTIAL |
| SNR/Doppler | Raw-count SNR localization and 20-packet SNR/Doppler robustness are complete. | VERIFIED_COMPLETE |
| EP/LLR/LDPC | Reliability, high-confidence-wrong-bit, variance and replay diagnostics exist. | VERIFIED_COMPLETE |
| Model mismatch | Older long-payload/video-link assets exist but use a different receiver and metric schema. | INCOMPATIBLE |
| Complexity/runtime | Current formal runtime/RLS audit exists; older profilers are legacy-method measurements. | PARTIAL |
| LTF/model | Formula, state mapping, channel scaling and LTF covariance audits exist; the simulation LTF is generated from noisy `H0`, not hardware capture. | VERIFIED_COMPLETE |
| Post-LDPC/BLER/Goodput | Codeword pass/BLER and payload-only Goodput exist; valid formal post-LDPC BER does not. | PARTIAL |

No new large MATLAB simulation was started during the inventory stage.
