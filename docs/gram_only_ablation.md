# Strict Gram-only ablation

## Definition

`GramOnlyLocalDAKalmanCausal_EP` uses the same causal candidate observations, LLR gate, local radius search, Kalman state model, innovation gate, Joseph update, receiver, and offline detector as Full Proposed. Its covariance is

\[
R_{\rm Gram}=\sigma_n^2\,\mathrm{kron}(G^{-T},I_{N_r}),
\]

where `G = X X'` is the selected candidate Gram matrix and the residual scale is fixed to the configured complex noise variance `sigma_n^2`. The same complex-to-real mapping and PSD floor used by the main estimator are applied. Thus the ablation preserves Gram geometry while removing residual-based scale adaptation.

## Small paired validation

One deterministic payload-169 packet at SNR 20 dB and Doppler 200 Hz was executed in the clean project with the same packet and receiver chain. The branch completed 7,436 data-aided updates; all channel estimates, states, and final covariance entries were finite. The smallest recorded RLS covariance eigenvalue was `2.94070e-4`, positive.

The smoke execution is recorded in `experiments/ablation/` and is not treated as a statistical result. The separate 20-packet independent-seed run is now complete; its packet-level and paired statistics are in `experiments/independent_seed_20261009/`.

## Fairness controls

- same packet generator and CRN construction;
- same candidate observations and LLR threshold;
- same radii and Gram rank/conditioning gates;
- same Kalman model and Joseph covariance update;
- same receiver and post-processing;
- no seed or unfavorable-packet filtering.

The existing `FixedRadius3LsCovOnlyCausal_EP` is not used as the Gram-only label: it combines residual scale with Gram-derived geometry and therefore does not isolate the Gram mechanism.
