function [gridTable,methodTable,snrTable,selection]=auditRawClipCalibrationSummary(detail,cfg)
%AUDITRAWCLIPCALIBRATIONSUMMARY Apply preregistered pooled and per-method constraints.
assert(all(ismember(unique(detail.scenarioIndex).',cfg.calibrationScenarios)));
gridTable=localScope(detail,"pooled");methodTable=localScope(detail,"method");snrTable=localScope(detail,"snr");
reference=gridTable(gridTable.clipLevel==Inf,:);assert(height(reference)==1);
for i=1:height(gridTable)
    C=gridTable.clipLevel(i);methods=methodTable(methodTable.clipLevel==C,:);rawMethods=methodTable(methodTable.clipLevel==Inf,:);
    [~,a,b]=intersect(methods.scopeValue,rawMethods.scopeValue,'stable');degradation=(methods.pooledNll(a)-rawMethods.pooledNll(b))./rawMethods.pooledNll(b);
    gridTable.maximumMethodNllDegradation(i)=max(degradation);
    gridTable.feasible(i)=gridTable.pooledNll(i)<=reference.pooledNll+1e-15&& ...
        gridTable.maximumMethodNllDegradation(i)<=cfg.methodNllTolerance&&gridTable.allHardBitsUnchanged(i)&& ...
        gridTable.preBitErrorDifference(i)==0&&gridTable.passToFailCount(i)<=reference.passToFailCount&& ...
        ~gridTable.hasNonfinite(i)&&localInvariantPass(cfg);
end
methodTable.maximumMethodNllDegradation=nan(height(methodTable),1);
methodTable.feasible=false(height(methodTable),1);
snrTable.maximumMethodNllDegradation=nan(height(snrTable),1);
snrTable.feasible=false(height(snrTable),1);
assert(isequal(gridTable.Properties.VariableNames,methodTable.Properties.VariableNames) ...
    &&isequal(gridTable.Properties.VariableNames,snrTable.Properties.VariableNames));
feasible=gridTable(gridTable.feasible,:);
if isempty(feasible),selectedC=NaN;else,[~,i]=min(feasible.pooledNll);selectedC=feasible.clipLevel(i);end
selection=struct('selectedC',selectedC,'feasibleCandidateCount',height(feasible), ...
    'hasNonInfFeasible',any(isfinite(feasible.clipLevel)),'selectedInf',isinf(selectedC), ...
    'boundaryHit',selectedC==cfg.clipGrid(1),'selectionUsedHoldout',false);
end
function pass=localInvariantPass(cfg)
if isfield(cfg,'invariantTestsPass'),pass=cfg.invariantTestsPass;else,pass=true;end
end
function summary=localScope(detail,scope)
if scope=="pooled",groups=table("ALL",'VariableNames',{'scopeValue'});elseif scope=="method",groups=table(unique(detail.method),'VariableNames',{'scopeValue'});else,groups=table(string(unique(detail.targetSnrDb)),'VariableNames',{'scopeValue'});end
clips=unique(detail.clipLevel,'stable');rows=cell(height(groups)*numel(clips),1);cursor=0;
for g=1:height(groups)
    for c=1:numel(clips)
        if scope=="pooled",x=detail(detail.clipLevel==clips(c),:);elseif scope=="method",x=detail(detail.clipLevel==clips(c)&detail.method==groups.scopeValue(g),:);else,x=detail(detail.clipLevel==clips(c)&detail.targetSnrDb==str2double(groups.scopeValue(g)),:);end
        cursor=cursor+1;recordPass=groupsummary(x,{'scenarioIndex','targetSnrDb','method'},'mean','decoderPass');
        rows{cursor}=table(scope,groups.scopeValue(g),clips(c),sum(x.nllSum)/sum(x.bitCount),1-mean(x.decoderPass), ...
            1-mean(recordPass.mean_decoderPass==1),sum(x.passToFail),sum(x.failToPass),sum(x.wrongHighConfidenceCount10), ...
            all(x.hardBitsUnchanged),sum(x.preBitErrorsRecord-x.preBitErrorsRawRecord), ...
            any(~isfinite(x.nllSum)|~isfinite(x.decoderRuntimeSec)),sum(x.decoderRuntimeSec), ...
            'VariableNames',{'scope','scopeValue','clipLevel','pooledNll','codewordBler','wholePayloadBler', ...
            'passToFailCount','failToPassCount','wrongHighConfidenceCount10','allHardBitsUnchanged', ...
            'preBitErrorDifference','hasNonfinite','decoderRuntimeSec'});
    end
end
summary=vertcat(rows{:});
end
