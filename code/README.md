# MATLAB code organization

The runtime-preserving MATLAB source closure remains at the repository root (`src/`, `audit_three_layer_helpers/`, `experiments/`, and the C1 entry points) because the original entry points resolve dependencies relative to their project root. This avoids changing algorithm code merely to impose a new folder layout.

The `code/plotting/` directory contains the release-side plotting entry, which is adapted only for the release directory's `data/figure_source/` and `figures/` locations. It does not alter the plotted data or channel-tracking algorithm.

