# Strict residual-only ablation

## Definition

`ResidualOnlyLocalDAKalmanCausal_EP` uses the same candidate selection and residual estimate as Full Proposed, but its update covariance is

\[
R_{\rm Residual}=\frac{\max(\sigma_n^2,\hat\sigma^2_{\rm residual})}{2}I_{N_s}.
\]

The geometry is isotropic in the real state and does not use the candidate Gram matrix. The candidate Gram matrix remains available only for the common feasibility/conditioning gate and for selecting the same candidate; it does not determine the residual-only covariance geometry. Only the residual estimate changes the scalar scale.

## Important naming correction

The historical/current `FixedRadius3LsCovOnlyCausal_EP` path computes LS covariance from both residual energy and the inverse Gram matrix. It is therefore a residual-plus-Gram LS covariance path, not Residual-only. It must not be relabeled in the paper.

## Numerical check

The one-packet clean-project smoke completed 7,765 updates with finite channel estimates, finite state, and finite final covariance. Positive definiteness follows directly from the construction because `max(noiseVar,sigma2Residual)>0` and the update applies the common PSD/Joseph checks. The diagnostic minimum-eigenvalue accumulator is not used as the acceptance criterion for this branch when a selected candidate carries the legacy mapping metadata; the covariance definition and update gate are the authoritative checks.

The 20-packet paired result is complete and is recorded in `experiments/independent_seed_20261009/`. It is used as independent mechanism evidence, not as a replacement for the formal 50-packet dataset.
