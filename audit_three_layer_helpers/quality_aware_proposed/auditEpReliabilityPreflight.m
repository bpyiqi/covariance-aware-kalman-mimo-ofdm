function source=auditEpReliabilityPreflight(cfg)
%AUDITEPRELIABILITYPREFLIGHT Validate only frozen dev12 chunks and checkpoint hashes.
schema=auditDecoderConfidenceCalibrationSchema();checkpoint=fullfile(cfg.sourceDirectory,schema.files.checkpoint);
assert(isfile(fullfile(cfg.sourceDirectory,schema.files.complete))&&isfile(checkpoint),'Frozen dev12 COMPLETE/checkpoint is missing.');
s=load(checkpoint);assert(string(s.status)=="complete"&&numel(s.chunkPaths)==12&&isequal(s.completedScenarios(:).',(1:12)));
assert(isequal(s.methods,cfg.methods));
for i=1:numel(s.chunkPaths),assert(isfile(s.chunkPaths(i))&&auditFileSha256(s.chunkPaths(i))==string(s.chunkHashes(i)), ...
    'Frozen raw-LLR chunk hash mismatch at scenario %d.',i);end
source=struct('checkpointPath',string(checkpoint),'chunkPaths',s.chunkPaths(:),'chunkHashes',s.chunkHashes(:), ...
    'receiverRows',s.receiverRows,'sourceCfg',s.cfg,'chunkCount',numel(s.chunkPaths));
end
