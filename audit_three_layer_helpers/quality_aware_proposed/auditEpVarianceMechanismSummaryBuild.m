function out=auditEpVarianceMechanismSummaryBuild(cfg,input)
%AUDITEPVARIANCEMECHANISMSUMMARYBUILD Aggregate frozen V2 rows without receiver work.
A=input.method;T=input.tail;F=input.floor;
A.method=string(A.method);A.layer=string(A.layer);A.errorStatus=string(A.errorStatus);T.method=string(T.method);T.layer=string(T.layer);T.errorStatus=string(T.errorStatus);F.method=string(F.method);F.layer=string(F.layer);
isFinal=ismember(A.method,cfg.finalMethods)&A.errorStatus=="all"&((A.method~="OJCD_LMMSE_EP_Adapted"&A.layer=="single")|(A.method=="OJCD_LMMSE_EP_Adapted"&A.layer=="jcd2"));
finalA=A(isFinal,:);assert(height(finalA)==45);
out.method=localMethodSummary(finalA,A,cfg);
out.paired=localPaired(finalA);
out.tail=localTailSummary(T,cfg);
out.floor=localFloorSummary(F,cfg);
out.ojcd=localOjcdSummary(A,F);
out.decision=localDecision(out,finalA);
end

function S=localMethodSummary(finalA,allA,~)
keys=unique(finalA(:,{'method','targetSnrDb','layer'}),'rows');rows=cell(height(keys),1);
for i=1:height(keys)
    x=finalA(finalA.method==keys.method(i)&finalA.targetSnrDb==keys.targetSnrDb(i)&finalA.layer==keys.layer(i),:);assert(height(x)==3);
    bitCount=sum(x.bitCount);bitErrorCount=sum(x.bitErrorCount);ber=bitErrorCount/bitCount;
    base=allA(allA.method=="BaseKalmanCausal_EP"&allA.targetSnrDb==keys.targetSnrDb(i)&allA.layer=="single",:);
    winsResidual=NaN;winsZe=NaN;
    if keys.method(i)~="BaseKalmanCausal_EP"
        [~,ix,ib]=intersect(x.scenarioIndex,base.scenarioIndex);assert(numel(ix)==3&&numel(ib)==3);
        winsResidual=sum(x.medianResidualPowerOverNoisePerRx(ix)<base.medianResidualPowerOverNoisePerRx(ib));
        winsZe=sum(x.medianXeErrorOverVe(ix)<base.medianXeErrorOverVe(ib));
    end
    rows{i}=table(keys.method(i),keys.targetSnrDb(i),keys.layer(i),numel(unique(x.scenarioIndex)),sum(x.recordCount),bitCount,bitErrorCount,ber,median(x.medianResidualPowerOverNoisePerRx,'omitnan'),min(x.medianResidualPowerOverNoisePerRx),max(x.medianResidualPowerOverNoisePerRx),median(x.medianXeErrorOverVe),max(x.p95XeErrorOverVe),max(x.p99XeErrorOverVe),median(x.medianLog10XpErrorOverVp,'omitnan'),max(x.p95Log10XpErrorOverVp),max(x.p99Log10XpErrorOverVp),sum(x.highConfidenceWrong10Count),sum(x.highConfidenceWrong40Count),sum(x.highConfidenceWrong160Count),sum(x.saturatedWrong700Count),sum(x.highConfidenceWrong40Count)/bitCount*1e6,sum(x.highConfidenceWrong40Count)/bitErrorCount,winsResidual,winsZe, ...
        'VariableNames',{'method','targetSnrDb','layer','scenarioCount','recordCount','bitCount','bitErrorCount','pooledPreLdpcBer','medianResidualPowerOverNoisePerRx','minimumResidualPowerOverNoisePerRx','maximumResidualPowerOverNoisePerRx','medianXeErrorOverVe','p95XeErrorOverVe','p99XeErrorOverVe','medianLog10XpErrorOverVp','p95Log10XpErrorOverVp','p99Log10XpErrorOverVp','highConfidenceWrong10Count','highConfidenceWrong40Count','highConfidenceWrong160Count','saturatedWrong700Count','highConfidenceWrong40PerMillionBits','highConfidenceWrong40ShareOfBitErrors','scenarioWinsResidualVersusBase','scenarioWinsMedianZeVersusBase'});
end
S=vertcat(rows{:});
end

function P=localPaired(finalA)
base=finalA(finalA.method=="BaseKalmanCausal_EP",:);cov=finalA(finalA.method=="CovarianceAwareLocalDAKalmanCausal_EP",:);[~,ib,ic]=intersect(base(:,{'scenarioIndex','targetSnrDb'}),cov(:,{'scenarioIndex','targetSnrDb'}),'rows');assert(numel(ib)==9);
b=base(ib,:);c=cov(ic,:);P=table(b.scenarioIndex,b.targetSnrDb,c.medianResidualPowerOverNoisePerRx./b.medianResidualPowerOverNoisePerRx,100*(1-c.medianResidualPowerOverNoisePerRx./b.medianResidualPowerOverNoisePerRx),c.medianXeErrorOverVe./b.medianXeErrorOverVe,100*(1-c.medianXeErrorOverVe./b.medianXeErrorOverVe),c.preLdpcBer./b.preLdpcBer,c.highConfidenceWrong40Count-b.highConfidenceWrong40Count,c.highConfidenceWrong40Count./b.highConfidenceWrong40Count, ...
    'VariableNames',{'scenarioIndex','targetSnrDb','residualRatioCovOverBase','residualReductionPercent','medianZeRatioCovOverBase','medianZeReductionPercent','preBerRatioCovOverBase','highConfidenceWrong40Difference','highConfidenceWrong40Ratio'});
end

function S=localTailSummary(T,cfg)
keep=ismember(T.method,cfg.finalMethods)&~(T.method=="OJCD_LMMSE_EP_Adapted"&T.layer=="jcd1");T=T(keep,:);keys=unique(T(:,{'method','targetSnrDb','layer','errorStatus'}),'rows');rows=cell(height(keys),1);
for i=1:height(keys)
    x=T(T.method==keys.method(i)&T.targetSnrDb==keys.targetSnrDb(i)&T.layer==keys.layer(i)&T.errorStatus==keys.errorStatus(i),:);
    allRow=T(T.method==keys.method(i)&T.targetSnrDb==keys.targetSnrDb(i)&T.layer==keys.layer(i)&T.errorStatus=="allBitsCorrect",:);
    z=median(x.medianXeErrorOverVe);r=median(x.medianResidualPowerOverNoisePerRx,'omitnan');
    if keys.errorStatus(i)=="highConfidenceWrong40",zRatio=z/median(allRow.medianXeErrorOverVe);rRatio=r/median(allRow.medianResidualPowerOverNoisePerRx,'omitnan');else,zRatio=NaN;rRatio=NaN;end
    rows{i}=table(keys.method(i),keys.targetSnrDb(i),keys.layer(i),keys.errorStatus(i),sum(x.recordCount),median(x.medianVe),median(x.medianVp),z,max(x.p95XeErrorOverVe),max(x.p99XeErrorOverVe),median(x.medianLog10XpErrorOverVp,'omitnan'),max(x.p95Log10XpErrorOverVp),max(x.p99Log10XpErrorOverVp),r,median(x.medianGramRcond),zRatio,rRatio, ...
        'VariableNames',{'method','targetSnrDb','layer','errorStatus','recordCount','medianVe','medianVp','medianXeErrorOverVe','p95XeErrorOverVe','p99XeErrorOverVe','medianLog10XpErrorOverVp','p95Log10XpErrorOverVp','p99Log10XpErrorOverVp','medianResidualPowerOverNoisePerRx','medianGramRcond','highWrong40MedianZeOverAllCorrect','highWrong40ResidualOverAllCorrect'});
end
S=vertcat(rows{:});
end

function S=localFloorSummary(F,~)
keys=unique(F(:,{'method','targetSnrDb','layer'}),'rows');rows=cell(height(keys),1);
for i=1:height(keys)
    x=F(F.method==keys.method(i)&F.targetSnrDb==keys.targetSnrDb(i)&F.layer==keys.layer(i),:);hits=sum(x.varianceFloorHits);rollbacks=sum(x.rollbackCount);negative=sum(x.negativePrecisionCandidates);n=sum(x.recordCount);
    availability="notCapturedInFrozenReplay";
    rows{i}=table(keys.method(i),keys.targetSnrDb(i),keys.layer(i),n,hits,hits/n,rollbacks,rollbacks/n,negative,negative/n,NaN,NaN,availability, ...
        'VariableNames',{'method','targetSnrDb','layer','recordCount','varianceFloorHits','varianceFloorHitsPerStreamRe','rollbackHits','rollbackHitsPerStreamRe','negativePrecisionHits','negativePrecisionHitsPerStreamRe','varianceFloorFractionPerProjection','rollbackFractionPerSiteUpdate','opportunityAvailability'});
end
S=vertcat(rows{:});
end

function S=localOjcdSummary(A,F)
A=A(A.method=="OJCD_LMMSE_EP_Adapted"&A.errorStatus=="all",:);rows=cell(6,1);q=0;
for snr=unique(A.targetSnrDb).'
    for layer=["jcd1","jcd2"]
        x=A(A.targetSnrDb==snr&A.layer==layer,:);f=F(F.method=="OJCD_LMMSE_EP_Adapted"&F.targetSnrDb==snr&F.layer==layer,:);q=q+1;
        rows{q}=table(snr,layer,median(x.medianVe),median(x.medianVp),median(x.medianXeErrorOverVe),max(x.p95XeErrorOverVe),max(x.p99XeErrorOverVe),median(x.medianLog10XpErrorOverVp,'omitnan'),sum(f.rollbackCount)/sum(f.recordCount),sum(f.varianceFloorHits)/sum(f.recordCount),NaN,NaN,"notCapturedInFrozenReplay", ...
            'VariableNames',{'targetSnrDb','layer','medianVe','medianVp','medianXeErrorOverVe','p95XeErrorOverVe','p99XeErrorOverVe','medianLog10XpErrorOverVp','rollbackHitsPerStreamRe','varianceFloorHitsPerStreamRe','preLdpcBer','bitErrorCount','unavailableFields'});
    end
end
S=vertcat(rows{1:q});
end

function D=localDecision(out,finalA)
P=out.paired;perfect=finalA(finalA.method=="PerfectCSI_EP",:);ojcd=out.method(out.method.method=="OJCD_LMMSE_EP_Adapted",:);
D=struct('covResidualLower',sum(P.residualRatioCovOverBase<1),'covZeLower',sum(P.medianZeRatioCovOverBase<1),'covBerLower',sum(P.preBerRatioCovOverBase<1),'covWrong40Lower',sum(P.highConfidenceWrong40Difference<0),'perfectResidualMin',min(perfect.medianResidualPowerOverNoisePerRx),'perfectResidualMax',max(perfect.medianResidualPowerOverNoisePerRx),'ojcdWrong40',sum(ojcd.highConfidenceWrong40Count));
end
