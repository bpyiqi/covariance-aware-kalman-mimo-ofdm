# Final Submission Plan

## Reuse now

Use the current robustness A/B tables and Figures 2--5 with explicit blockwise-calibrated wording. Use the formal NMSE and Pre-LDPC BER values only after the source-hash binding is resolved or the exact historical source snapshot is archived with the submission package. Use the existing mechanism, radius, NIS and EP/LDPC diagnostics as bounded explanation and appendix evidence.

## Do not repeat

Do not repeat the existing 20-scenario raw SNR/BLER diagnosis, the EP/LLR/LDPC anomaly audits, the 20-packet robustness A/B grid, the current radius/NIS mechanism diagnostics, or the current independent SNR scans. They already contain raw counts, seeds, pairing hashes or diagnostic reports.

Do not reuse legacy `DataKalmanNoGram`, `DataKalmanNoGate`, `ReliableDataKalman`, `AdaptiveKalman` or `EMKalman` outputs as C1 ablations.

## Minimum remaining work

The minimum scientifically meaningful package is: source binding for the formal table; one explicit Gram-only current-version control; a decision to implement or rename the residual-plus-Gram control; and, if desired for stronger robustness, a 20-physical-packet exact-center independent seed check. Post-LDPC BER repair is required only if that metric is claimed.

## Paper wording constraints

Use “Pre-LDPC BER” rather than “BER” where ambiguity exists. Describe Goodput as payload-only unless full frame overhead is explicitly calculated. Do not claim statistically significant Goodput gain versus Fixed when the paired CI includes zero. Describe the robustness protocol as blockwise calibrated, not strict symbol-causal or real-time. State that the LTF initial estimate is a simulated noisy estimate constructed from the true initial channel and noise model, not a measured hardware LTF capture. Report raw nonmonotonic BLER points and counts without smoothing or cherry-picking.

## Decision gate

C1 is close to submission for an English rewrite, but it is not yet at the strictest Physical Communication submission gate until source binding and the covariance-mechanism ablation label are closed. A full 50-packet rerun is not currently justified; it becomes necessary only if the exact frozen source snapshot cannot be recovered or the equivalence check fails.
