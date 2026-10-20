function auditValidateOjcdDiagnostic20Tables(tables, expectedPhysicalPackets, methodCount)
%AUDITVALIDATEOJCDDIAGNOSTIC20TABLES Validate schemas and paired hashes.
schema=auditOjcdDiagnostic20Schema();names=fieldnames(schema);
for index=1:numel(names)
    tableName=names{index};assert(istable(tables.(tableName)),'Diagnostic artifact %s is not a table.',tableName);
    missing=setdiff(schema.(tableName),tables.(tableName).Properties.VariableNames);
    assert(isempty(missing),'Diagnostic artifact %s is missing columns: %s',tableName,strjoin(missing,','));
end
assert(height(tables.packet)==expectedPhysicalPackets*methodCount,'Unexpected packet-level row count.');
assert(height(tables.condition)==expectedPhysicalPackets,'Unexpected condition-tail row count.');
assert(height(tables.hash)==expectedPhysicalPackets*methodCount,'Unexpected pairing-hash row count.');
keys=unique(tables.hash(:,{'payloadSymbols','packetIndex'}),'rows');hashNames={'conditionSeed','packetSeed','transmitBitsHash','channelHash','noiseHash','receivedSignalHash','pilotObservationHash','paddingMaskHash'};
for keyIndex=1:height(keys)
    rows=tables.hash(tables.hash.payloadSymbols==keys.payloadSymbols(keyIndex)&tables.hash.packetIndex==keys.packetIndex(keyIndex),:);
    assert(height(rows)==methodCount,'A pairing group has the wrong method count.');
    for hashIndex=1:numel(hashNames),values=rows.(hashNames{hashIndex});assert(all(values==values(1)),'Pairing mismatch in %s.',hashNames{hashIndex});end
end
end
