function bootstrap=auditRawClipBootstrap(detail,cfg)
%AUDITRAWCLIPBOOTSTRAP Scenario-unit candidate selection bootstrap.
scenarios=cfg.calibrationScenarios;C=cfg.clipGrid;M=cfg.methods;S=numel(scenarios);
nll=zeros(S,numel(M),numel(C));bits=zeros(S,numel(M),numel(C));ptf=zeros(S,numel(C));hard=true(S,numel(C));pre=zeros(S,numel(C));
for s=1:S
    for c=1:numel(C)
        z=detail(detail.scenarioIndex==scenarios(s)&detail.clipLevel==C(c),:);ptf(s,c)=sum(z.passToFail);hard(s,c)=all(z.hardBitsUnchanged);pre(s,c)=sum(z.preBitErrorsRecord-z.preBitErrorsRawRecord);
        for m=1:numel(M)
            x=z(z.method==M(m),:);nll(s,m,c)=sum(x.nllSum);bits(s,m,c)=sum(x.bitCount);
        end
    end
end
state=rng;cleanup=onCleanup(@()rng(state));rng(cfg.bootstrapSeed,'twister');rows=cell(cfg.bootstrapCount,1);
for b=1:cfg.bootstrapCount
    sampled=randi(S,S,1);
    loss=reshape(sum(nll(sampled,:,:),1)./sum(bits(sampled,:,:),1),numel(M),numel(C));
    pooled=reshape(sum(nll(sampled,:,:),[1 2])./sum(bits(sampled,:,:),[1 2]),1,numel(C));
    raw=loss(:,end);degradation=max((loss-raw)./raw,[],1);feasible=pooled<=pooled(end)+1e-15&degradation<=cfg.methodNllTolerance& ...
        all(hard(sampled,:),1)&sum(pre(sampled,:),1)==0&sum(ptf(sampled,:),1)<=sum(ptf(sampled,end));
    if isfield(cfg,'invariantTestsPass')&&~cfg.invariantTestsPass,feasible(:)=false;end
    candidates=find(feasible);if isempty(candidates),selected=NaN;else,[~,q]=min(pooled(candidates));selected=C(candidates(q));end
    reduction=NaN;if ~isnan(selected),reduction=(pooled(end)-pooled(C==selected))/pooled(end);end
    rows{b}=table(b,selected,numel(candidates),reduction,selected==C(1),isinf(selected), ...
        'VariableNames',{'bootstrapIndex','selectedC','feasibleCandidateCount','pooledNllReduction','boundaryHit','selectedInf'});
end
bootstrap=vertcat(rows{:});
end
