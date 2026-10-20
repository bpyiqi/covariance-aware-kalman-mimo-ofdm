# Results and source hashes

The formal 50-packet result and frozen method manifest were copied unchanged. Binding is **UNVERIFIED / EXISTS_UNVERIFIED**: the frozen estimator hash differs from the current estimator hash. Matching numerical outputs are not treated as proof of source identity. No frozen hash was edited.

`sha256_manifest.csv` records current source and copied-file hashes.

Relevant comparison:

| File | Frozen-manifest SHA256 | Current clean-source SHA256 | Status |
|---|---|---|---|
| `auditCovarianceAwareFinalValidation50.m` | `E6CED466293AD205D0312203994839E0DE80C3636D8CF4891189139420A97517` | same | matched |
| `auditCovarianceAwareFinalValidation50RunCore.m` | `2D3B04CEF562C192793407CA55295E304541465DF42A2D079B319CB462C3CD89` | same | matched |
| `auditMechanismRunSingleEstimator.m` | `CF3291AC1D8BD967B4296CFA078DEAE8DE1235A52A99F8450D1777C5EE637E45` | `03451DF4A5EEE32E5EC71169A6490D31999C9434DD5C1AEF38B10D6A0CF935FB` | mismatch |

The complete source closure therefore cannot be bound to the formal result from the available evidence.

The deterministic self-tests regenerated three clean-only implementation-audit artifacts (`ojcd_baseline_implementation_audit/ojcd_covariance_design_audit.txt`, `ojcd_baseline_implementation_audit/protected_file_hashes.txt`, and `quality_aware_proposed_implementation_audit/quality_aware_protected_hashes.csv`). Their original source hashes remain unchanged in the manifest; clean-side hashes were refreshed after testing.
