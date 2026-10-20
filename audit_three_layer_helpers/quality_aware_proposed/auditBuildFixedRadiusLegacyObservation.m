function observation = auditBuildFixedRadiusLegacyObservation(X,Y,targetIndex,validMask,reliability,fixedRadius,cfg)
%AUDITBUILDFIXEDRADIUSLEGACYOBSERVATION Exact-radius old-RDA LS candidate.
assert(ismember(fixedRadius,[1 2 3]),'Configured fixed radius must be 1, 2, or 3.');
observation=auditBuildLocalMimoPseudoObservation(X,Y,targetIndex,validMask,reliability,cfg.radii,cfg.llrThreshold,fixedRadius);
if observation.accepted,assert(observation.selectedRadius==fixedRadius,'Fixed-radius branch changed radius.');end
end
