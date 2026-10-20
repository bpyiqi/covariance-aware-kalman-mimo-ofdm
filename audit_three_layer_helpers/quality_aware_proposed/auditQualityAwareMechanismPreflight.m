function evidence = auditQualityAwareMechanismPreflight(root,cfg,outputDirectory)
%AUDITQUALITYAWAREMECHANISMPREFLIGHT Frozen hash/schema/overwrite gates.
base=auditQualityAwareDiagnostic20Preflight(root,auditQualityAwareDiagnostic20Config(root),[tempname '_mechanism_preflight']);
assert(exist(cfg.frozenPairingPath,'file')==2,'Frozen diagnostic20 pairing hashes are missing.');frozen=readtable(cfg.frozenPairingPath,'TextType','string');required=auditQualityAwareMiniSchema().hash;
assert(height(frozen)==440&&height(unique(frozen(:,{'payloadSymbols','packetIndex'}),'rows'))==40,'Frozen pairing table dimensions changed.');assert(isempty(setdiff(required,frozen.Properties.VariableNames)),'Frozen pairing hash schema is incomplete.');
localAssertFrozenGroups(frozen,required);
assert(cfg.mechanismMasterSeed==20260720&&cfg.mechanismPacketCountPerCondition==20&&numel(cfg.mechanismMethods)==10&&cfg.fixedRadius==3,'Mechanism configuration drift.');
assert(cfg.frozenHashAbsoluteTolerance==1e-5,'Frozen-hash absolute tolerance drift.');
resultPath=fullfile(outputDirectory,'quality_aware_mechanism_packet_level.csv');assert(exist(resultPath,'file')~=2,'Refusing to overwrite completed mechanism diagnostic: %s',resultPath);
evidence=base;evidence.frozenPairingTable=frozen;evidence.frozenPairingSchemaPass=true;evidence.frozenPairingInternalConsistencyPass=true;evidence.outputCollisionFree=true;
end

function localAssertFrozenGroups(frozen,required)
keys=unique(frozen(:,{'payloadSymbols','packetIndex'}),'rows');columns=required([2 5:numel(required)]);
for index=1:height(keys)
    rows=frozen(frozen.payloadSymbols==keys.payloadSymbols(index)&frozen.packetIndex==keys.packetIndex(index),:);
    assert(height(rows)==11,'Frozen pairing method count changed at payloadSymbols=%d packetIndex=%d.',keys.payloadSymbols(index),keys.packetIndex(index));
    for column=columns
        values=rows.(column{1});assert(all(values==values(1)),'Frozen pairing rows disagree in %s.',column{1});
    end
end
end
