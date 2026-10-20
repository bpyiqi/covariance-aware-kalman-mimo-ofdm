function summary=localSummarizeExecutionLedger(ledger)
summary=struct('attemptedActualReceiverRuns',0,'completedActualReceiverRuns',0,'uniquePhysicalInputsActuallyUsed',0,'captureOffRunsAttempted',0,'captureOnRunsAttempted',0,'captureOffRunsCompleted',0,'captureOnRunsCompleted',0,'syntheticRuns',0,'actualReceiverRuns',0,'uniquePhysicalSeedIdsObserved',0,'newPhysicalSeedsActuallyGenerated',NaN,'outputDirectoryCreated',false,'COMPLETEWritten',false);
if ~istable(ledger)||height(ledger)==0,return;end
actual=localLedgerLogical(ledger,'isActualReceiverRun',false); attempted=localLedgerLogical(ledger,'attempted',false); completed=localLedgerLogical(ledger,'completed',false); mode=localLedgerString(ledger,'captureMode');
summary.attemptedActualReceiverRuns=nnz(actual&attempted); summary.completedActualReceiverRuns=nnz(actual&completed); summary.actualReceiverRuns=summary.completedActualReceiverRuns;
summary.captureOffRunsAttempted=nnz(actual&attempted&mode=="off"); summary.captureOnRunsAttempted=nnz(actual&attempted&mode=="on"); summary.captureOffRunsCompleted=nnz(actual&completed&mode=="off"); summary.captureOnRunsCompleted=nnz(actual&completed&mode=="on"); summary.syntheticRuns=nnz(~actual&attempted);
ids=localLedgerString(ledger,'physicalInputId'); valid=~ismissing(ids)&strlength(strtrim(ids))>0; summary.uniquePhysicalInputsActuallyUsed=numel(unique(ids(valid)));
seedIds=localLedgerString(ledger,'physicalSeedId'); validSeed=~ismissing(seedIds)&strlength(strtrim(seedIds))>0; summary.uniquePhysicalSeedIdsObserved=numel(unique(seedIds(validSeed)));
if ismember('newPhysicalSeedGenerated',ledger.Properties.VariableNames)
    generated=localLedgerLogical(ledger,'newPhysicalSeedGenerated',false); generated=generated&validSeed; summary.newPhysicalSeedsActuallyGenerated=numel(unique(seedIds(generated)));
end
end

function value=localLedgerLogical(T,name,default)
if ismember(name,T.Properties.VariableNames),value=logical(T.(name));else,value=repmat(default,height(T),1);end
end
function value=localLedgerString(T,name)
if ~istable(T)||~ismember(name,T.Properties.VariableNames),value=strings(height(T),1);return;end
raw=T.(name); if isstring(raw),value=raw(:);elseif ischar(raw),value=string(cellstr(raw));elseif iscell(raw),value=string(raw(:));elseif iscategorical(raw),value=string(raw(:));else,value=string(raw(:));end
end
