function [summary,transitions,gates]=auditRawClipHoldoutSummary(detail,cfg,Cstar)
%AUDITRAWCLIPHOLDOUTSUMMARY Evaluate frozen Cstar without influencing selection.
assert(all(ismember(unique(detail.scenarioIndex).',cfg.holdoutScenarios)));
raw=detail(detail.clipLevel==Inf,:);raw.mode=repmat("raw",height(raw),1);
clipped=detail(detail.clipLevel==Cstar,:);clipped.mode=repmat("clipped",height(clipped),1);x=[raw;clipped];
scopes=["pooled" cfg.methods "SNR="+string(unique(x.targetSnrDb).')];rows=cell(numel(scopes)*2,1);cursor=0;
for scope=scopes
    for mode=["raw","clipped"]
        z=x(x.mode==mode,:);if scope~="pooled",if startsWith(scope,"SNR="),z=z(z.targetSnrDb==str2double(extractAfter(scope,"=")),:);else,z=z(z.method==scope,:);end,end
        records=groupsummary(z,{'scenarioIndex','targetSnrDb','method'},'mean','decoderPass');cursor=cursor+1;
        rows{cursor}=table(scope,mode,sum(z.nllSum)/sum(z.bitCount),1-mean(z.decoderPass),1-mean(records.mean_decoderPass==1), ...
            mean(z.decoderPass),sum(z.passToFail),sum(z.failToPass),localWeighted(z.wrongBitMeanAbsLlr,z.preBitErrorsRecord), ...
            max(z.wrongBitMaxAbsLlr,[],'omitnan'),sum(z.wrongHighConfidenceCount10),sum(z.decoderRuntimeSec), ...
            'VariableNames',{'scope','mode','pooledNll','codewordBler','wholePayloadBler','codewordPassRate', ...
            'passToFailCount','failToPassCount','wrongBitMeanAbsLlr','wrongBitMaxAbsLlr', ...
            'wrongHighConfidenceCount10','decoderRuntimeSec'});
    end
end
summary=vertcat(rows{:});transitions=localTransitions(x);pooledRaw=summary(summary.scope=="pooled"&summary.mode=="raw",:);pooledClip=summary(summary.scope=="pooled"&summary.mode=="clipped",:);
methodRaw=summary(ismember(summary.scope,cfg.methods)&summary.mode=="raw",:);methodClip=summary(ismember(summary.scope,cfg.methods)&summary.mode=="clipped",:);
[~,a,b]=intersect(methodClip.scope,methodRaw.scope,'stable');methodDegradation=max((methodClip.pooledNll(a)-methodRaw.pooledNll(b))./methodRaw.pooledNll(b));
gates=struct('pooledNllNotWorse',pooledClip.pooledNll<=pooledRaw.pooledNll,'maximumMethodNllDegradation',methodDegradation, ...
    'methodNllGate',methodDegradation<=cfg.methodNllTolerance,'hardBitsUnchanged',all(x.hardBitsUnchanged), ...
    'preBerUnchanged',sum(x.preBitErrorsRecord-x.preBitErrorsRawRecord)==0, ...
    'passToFailNotIncreased',pooledClip.passToFailCount<=pooledRaw.passToFailCount, ...
    'reverseCrossingNotIncreased',localReverse(x,"clipped")<=localReverse(x,"raw"), ...
    'hasNonfinite',any(~isfinite(x.nllSum)|~isfinite(x.decoderRuntimeSec)),'selectionUsedHoldout',false);
end
function T=localTransitions(x)
T=x(:,{'scenarioIndex','targetSnrDb','method','codewordIndex','clipLevel','mode','rawDecoderPass','decoderPass','passToFail','failToPass'});
end
function count=localReverse(detail,mode)
detail=detail(detail.mode==mode,:);keys=unique(detail(:,{'method','scenarioIndex','codewordIndex'}),'rows');count=0;
for i=1:height(keys)
    z=sortrows(detail(detail.method==keys.method(i)&detail.scenarioIndex==keys.scenarioIndex(i)& ...
        detail.codewordIndex==keys.codewordIndex(i),:),'targetSnrDb');
    count=count+nnz(z.decoderPass(1:end-1)&~z.decoderPass(2:end));
end
end
function value=localWeighted(x,w),valid=isfinite(x)&w>0;if any(valid),value=sum(x(valid).*w(valid))/sum(w(valid));else,value=0;end,end
