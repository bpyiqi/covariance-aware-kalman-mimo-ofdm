function preflight=auditRawClipPreflight(cfg)
%AUDITRAWCLIPPREFLIGHT Verify the frozen source experiment without writing it.
schema=auditDecoderConfidenceCalibrationSchema();checkpoint=fullfile(cfg.sourceDirectory,schema.files.checkpoint);
assert(isfile(fullfile(cfg.sourceDirectory,schema.files.complete)),'Source dev12 COMPLETE is missing.');
assert(isfile(checkpoint),'Source dev12 checkpoint is missing.');source=load(checkpoint);
assert(string(source.status)=="complete"&&isequal(source.completedScenarios(:).',(1:12)));
assert(isequal(source.calibrationScenarios,cfg.calibrationScenarios)&&isequal(source.holdoutScenarios,cfg.holdoutScenarios));
assert(isequal(source.methods,cfg.methods)&&numel(source.chunkPaths)==12&&numel(source.chunkHashes)==12);
for i=1:12
    assert(isfile(source.chunkPaths(i)),'Missing source raw-LLR chunk %d.',i);
    actual=auditFileSha256(source.chunkPaths(i));
    assert(actual==string(source.chunkHashes(i)),'Source raw-LLR chunk hash mismatch at scenario %d.',i);
end
preflight=struct('checkpointPath',string(checkpoint),'chunkPaths',source.chunkPaths(:), ...
    'chunkHashes',source.chunkHashes(:),'receiverRows',source.receiverRows, ...
    'sourceMasterSeed',source.masterSeed,'sourceScenarioSeeds',source.scenarioSeeds, ...
    'chunkCount',numel(source.chunkPaths),'sourceComplete',true);
end
