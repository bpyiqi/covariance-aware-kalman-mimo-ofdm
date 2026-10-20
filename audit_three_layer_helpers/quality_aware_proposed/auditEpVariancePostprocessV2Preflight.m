function meta=auditEpVariancePostprocessV2Preflight(cfg)
%AUDITEPVARIANCEPOSTPROCESSV2PREFLIGHT Validate source without loading giant rows/extreme fields.
resultFile=fullfile(cfg.sourceDirectory,'ep_variance_replay_results.mat');assert(isfile(resultFile)&&isfile(fullfile(cfg.sourceDirectory,'COMPLETE')),'Frozen replay45 result/COMPLETE is missing.');
meta=load(resultFile,'cfg','source','completed');assert(isequal(meta.completed(:).',[1 2 3])&&numel(meta.source.chunkPaths)==12);
for i=1:3,assert(isfile(fullfile(cfg.sourceDirectory,sprintf('ep_variance_scenario_%02d.mat',i))),'Frozen scenario MAT is missing.');end
for i=1:numel(meta.source.chunkPaths),assert(auditFileSha256(meta.source.chunkPaths(i))==string(meta.source.chunkHashes(i)),'dev12 chunk hash mismatch.');end
end
