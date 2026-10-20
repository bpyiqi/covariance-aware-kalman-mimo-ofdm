function result = auditQualityAwareProposedCausalEstimates(cfg,online)
%AUDITQUALITYAWAREPROPOSEDCAUSALESTIMATES Four isolated causal DA branches.
% online exposes only pilot observations, current received data and padding masks.
required={'pilotObservation','receivedData','dataSubcarriers','validDataMask','noiseVar','rho'};
missing=setdiff(required,fieldnames(online));assert(isempty(missing),'Missing online fields: %s',strjoin(missing,','));
K=size(online.pilotObservation,1);N=size(online.pilotObservation,2);D=numel(online.dataSubcarriers);F=cfg.stateDimension;
assert(size(online.receivedData,1)==D&&size(online.receivedData,2)==N&&isequal(size(online.validDataMask),[D N]));
A=reshape(permute(single(ofdm.complexToFeatures(online.pilotObservation)),[1 3 2]),K*F,N);
stateVariance=max(mean(double(A).^2,2),1e-5);Q=max(1-online.rho^2,1e-8).*stateVariance;Rpilot=max(online.noiseVar/2,1e-8);
branches=cfg.methods;states=cell(numel(branches),1);audits=cell(numel(branches),1);branchRuntimeSeconds=zeros(numel(branches),1);
for branch=1:numel(branches)
    covariance=zeros(K,F,F);for k=1:K,index=k+(0:F-1)*K;covariance(k,:,:)=diag(stateVariance(index)+Rpilot);end
    states{branch}=struct('x',double(A(:,1)),'Pfull',covariance, ...
        'H',complex(zeros(K,N,2,2,'single')));
    states{branch}.H(:,1,:,:)=online.pilotObservation(:,1,:,:);
    audits{branch}=localAudit(D,N,D*N*numel(cfg.radii),branch==4);
end
for n=1:N
    if n>1
        for branch=1:numel(branches)
            branchTimer=tic;
            state=states{branch};
            for k=1:K
                index=k+(0:F-1)*K;prediction=online.rho*state.x(index);Pprevious=squeeze(state.Pfull(k,:,:));
                Pprediction=online.rho^2*Pprevious+diag(Q(index));gain=Pprediction/(Pprediction+Rpilot*eye(F));
                state.x(index)=prediction+gain*(double(A(index,n))-prediction);baseA=eye(F)-gain;
                Ppost=baseA*Pprediction*baseA'+gain*(Rpilot*eye(F))*gain';state.Pfull(k,:,:)=(Ppost+Ppost')/2;
            end
            state.H(:,n,:,:)=ofdm.featuresToComplex(permute(reshape(single(state.x),K,F),[1 3 2]));states{branch}=state;
            branchRuntimeSeconds(branch)=branchRuntimeSeconds(branch)+toc(branchTimer);
        end
    end
    frozenH=cellfun(@(state)squeeze(state.H(:,n,:,:)),states,'UniformOutput',false);
    decisions=cell(numel(branches),1);absoluteLlr=cell(numel(branches),1);
    for branch=1:numel(branches)
        branchTimer=tic;
        [decisions{branch},absoluteLlr{branch}]=localDecisions(frozenH{branch},online.receivedData(:,n,:),online.dataSubcarriers,online.noiseVar);
        branchRuntimeSeconds(branch)=branchRuntimeSeconds(branch)+toc(branchTimer);
    end
    for branch=1:numel(branches)
        branchTimer=tic;
        state=states{branch};pilotSnapshot=state.x;covarianceSnapshot=state.Pfull;
        for target=1:D
            if ~online.validDataMask(target,n),audits{branch}.paddingTargetCount=audits{branch}.paddingTargetCount+1;continue;end
            targetSubcarrier=online.dataSubcarriers(target);index=targetSubcarrier+(0:F-1)*K;hPilot=pilotSnapshot(index);PPilot=squeeze(covarianceSnapshot(targetSubcarrier,:,:));
            candidates=localCandidates(branch,decisions{branch},squeeze(online.receivedData(:,n,:)).',absoluteLlr{branch},target,online.validDataMask(:,n),hPilot,PPilot,online.noiseVar,cfg);
            selection=auditSelectQualityAwareWindow(candidates,cfg);
            if branch==1
                selection=localOldSelection(decisions{branch},squeeze(online.receivedData(:,n,:)).',absoluteLlr{branch},target,online.validDataMask(:,n),hPilot,PPilot,online.noiseVar,cfg);
                Roverride=Rpilot*eye(F);
            elseif branch==2
                Roverride=Rpilot*eye(F);
            else
                Roverride=[];
            end
            audits{branch}=localAccumulateCandidates(audits{branch},candidates,n,target,targetSubcarrier,selection.selectedRadius);
            [hFinal,PFinal,updateAudit]=auditQualityAwareDaKalmanUpdate(hPilot,PPilot,selection,Roverride,cfg);
            state.x(index)=hFinal;state.Pfull(targetSubcarrier,:,:)=PFinal;state.H(targetSubcarrier,n,:,:)=auditFeatureVectorToChannelMatrix(hFinal);
            audits{branch}.daUpdateCount(target,n)=updateAudit.daUpdateCount;audits{branch}.selectedRadius(target,n)=selection.selectedRadius;
            audits{branch}.candidateCount(target,n)=selection.validCandidateCount;
            if ~selection.accepted,audits{branch}.noCandidateCount=audits{branch}.noCandidateCount+1;else,audits{branch}.selectedRadiusCount(selection.selectedRadius)=audits{branch}.selectedRadiusCount(selection.selectedRadius)+1;end
            if min(real(eig(PFinal)))<-1e-10,audits{branch}.covarianceNonPsdCount=audits{branch}.covarianceNonPsdCount+1;end
        end
        states{branch}=state;
        branchRuntimeSeconds(branch)=branchRuntimeSeconds(branch)+toc(branchTimer);
    end
end
result=struct('methodNames',branches,'channelEstimates',{cellfun(@(s)s.H,states,'UniformOutput',false)}, ...
    'stateAudits',{audits},'futureSymbolReadCount',0,'testTruthOnlineUseCount',0, ...
    'crossMethodStateSharingCount',0,'withinSymbolDaFeedbackEvents',0, ...
    'branchRuntimeSeconds',branchRuntimeSeconds);
end

function [X,absLlr]=localDecisions(Hseed,ySlice,data,noiseVar)
D=numel(data);X=complex(zeros(2,D));absLlr=zeros(4,2,D);
for d=1:D
    xeq=ofdm.mmseEqualize2x2(double(reshape(ySlice(d,1,:),2,1)),double(squeeze(Hseed(data(d),:,:))),noiseVar);
    bits=ofdm.qam16DemodBits(xeq);X(:,d)=ofdm.qam16ModBits(double(bits));
    absLlr(:,:,d)=reshape(abs(ofdm.qam16DemodLlr(xeq,noiseVar)),4,2);
end
end
function candidates=localCandidates(branch,X,Y,L,target,valid,h,P,noise,cfg)
if branch==3,radii=cfg.fixedRadius;else,radii=cfg.radii;end
candidates=repmat(auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,radii(1),h,P,noise,cfg),1,numel(radii));
for i=1:numel(radii),candidates(i)=auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,radii(i),h,P,noise,cfg);end
end
function selection=localOldSelection(X,Y,L,target,valid,h,P,noise,cfg)
selection=struct('accepted',false,'candidate',[],'selectedRadius',NaN,'selectedScore',Inf,'validCandidateCount',0);
reliability=squeeze(min(min(L,[],1),[],2));old=auditBuildLocalMimoPseudoObservation(X,Y,target,valid,reliability,cfg.radii,cfg.llrThreshold,[]);
if ~old.accepted,return;end
c=auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,old.selectedRadius,h,P,noise,cfg);c.candidateFeasible=true;c.zDa=old.feature;
selection.accepted=true;selection.candidate=c;selection.selectedRadius=old.selectedRadius;selection.selectedScore=c.qualityScore;selection.validCandidateCount=1;
end
function a=localAudit(D,N,maxCandidates,storeCandidateRecords)
a=struct('daUpdateCount',zeros(D,N),'selectedRadius',nan(D,N),'candidateCount',zeros(D,N), ...
    'paddingTargetCount',0,'selectedRadiusCount',zeros(1,3),'noCandidateCount',0, ...
    'innovationRejectCount',0,'candidateCountBeforeInnovation',0,'candidateCountAfterInnovation',0, ...
    'rdaTrace',nan(maxCandidates,1),'normalizedNis',nan(maxCandidates,1), ...
    'decisionInflation',nan(maxCandidates,1),'nisInflation',nan(maxCandidates,1), ...
    'candidateAuditCursor',0,'eigenFloorAppliedCount',0,'solverFailureCount',0, ...
    'covarianceNonPsdCount',0,'pilotUpdateCount',D*max(N-1,0), ...
    'storeCandidateRecords',storeCandidateRecords,'candidateRecordCursor',0, ...
    'candidateRecords',localCandidateRecords(maxCandidates*double(storeCandidateRecords)));
end
function a=localAccumulateCandidates(a,candidates,symbolIndex,targetIndex,targetSubcarrier,selectedRadius)
for i=1:numel(candidates)
    candidate=candidates(i);
    if ~isempty(candidate.Rdecision)
        a.candidateCountBeforeInnovation=a.candidateCountBeforeInnovation+1;a.candidateAuditCursor=a.candidateAuditCursor+1;cursor=a.candidateAuditCursor;
        a.rdaTrace(cursor)=trace(candidate.Rda);a.normalizedNis(cursor)=candidate.normalizedNis;a.decisionInflation(cursor)=candidate.decisionInflationFactor;a.nisInflation(cursor)=candidate.nisInflationFactor;
        if isfield(candidate.mappingAudit,'eigenFloorApplied'),a.eigenFloorAppliedCount=a.eigenFloorAppliedCount+double(candidate.mappingAudit.eigenFloorApplied);end
    end
    if candidate.rejectedByInnovation,a.innovationRejectCount=a.innovationRejectCount+1;end
    if candidate.candidateFeasible,a.candidateCountAfterInnovation=a.candidateCountAfterInnovation+1;end
    if a.storeCandidateRecords
        a.candidateRecordCursor=a.candidateRecordCursor+1;cursor=a.candidateRecordCursor;records=a.candidateRecords;
        records.symbolIndex(cursor)=symbolIndex;records.targetIndex(cursor)=targetIndex;records.targetSubcarrier(cursor)=targetSubcarrier;records.candidateRadius(cursor)=candidate.radius;
        records.onlineQualityScore(cursor)=candidate.qualityScore;records.posteriorTraceRatio(cursor)=candidate.qualityScore;records.normalizedResidual(cursor)=candidate.normalizedResidual;records.gramRcond(cursor)=candidate.gramRcond;records.effectiveSampleCount(cursor)=candidate.effectiveSampleCount;
        records.meanDecisionCorrectProbability(cursor)=candidate.meanDecisionCorrectProbability;records.decisionInflationFactor(cursor)=candidate.decisionInflationFactor;records.normalizedNis(cursor)=candidate.normalizedNis;records.nisInflationFactor(cursor)=candidate.nisInflationFactor;
        if ~isempty(candidate.Rls),records.traceRls(cursor)=trace(candidate.Rls);end;if ~isempty(candidate.Rda),records.traceRda(cursor)=trace(candidate.Rda);end
        records.feasibleBeforeInnovation(cursor)=~isempty(candidate.Rdecision);records.acceptedAfterInnovation(cursor)=candidate.candidateFeasible;records.selectedByOnlineMethod(cursor)=candidate.candidateFeasible&&candidate.radius==selectedRadius;
        if ~isempty(candidate.zDa),records.hDaFeature(:,cursor)=candidate.zDa;end;a.candidateRecords=records;
    end
end
end
function records=localCandidateRecords(count)
records=struct('symbolIndex',zeros(count,1),'targetIndex',zeros(count,1), ...
    'targetSubcarrier',zeros(count,1),'candidateRadius',zeros(count,1), ...
    'onlineQualityScore',nan(count,1),'posteriorTraceRatio',nan(count,1), ...
    'normalizedResidual',nan(count,1),'gramRcond',nan(count,1), ...
    'effectiveSampleCount',zeros(count,1),'meanDecisionCorrectProbability',nan(count,1), ...
    'decisionInflationFactor',nan(count,1),'normalizedNis',nan(count,1), ...
    'nisInflationFactor',nan(count,1),'traceRls',nan(count,1),'traceRda',nan(count,1), ...
    'feasibleBeforeInnovation',false(count,1),'acceptedAfterInnovation',false(count,1), ...
    'selectedByOnlineMethod',false(count,1),'hDaFeature',nan(8,count));
end
