function source=auditEpVarianceReplay45Preflight(cfg)
%AUDITEPVARIANCEREPLAY45PREFLIGHT Reuse frozen dev12 seed/hashes only.
source=auditEpReliabilityPreflight(cfg);assert(isequal(source.sourceCfg.Npayload,507)&&source.sourceCfg.fdHz==200);
end
