function result = auditMechanismRunSingleEstimator(cfg,online,method,options)
%AUDITMECHANISMRUNSINGLEESTIMATOR One causal state chain, no online truth.
if nargin<4,options=struct();end;if ~isfield(options,'bypassCapture'),options.bypassCapture=false;end
required={'pilotObservation','receivedData','validDataMask','noiseVar','rho'};missing=setdiff(required,fieldnames(online));assert(isempty(missing),'Estimator online packet is missing fields: %s.',strjoin(missing,', '));
K=cfg.NFFT;N=size(online.pilotObservation,2);D=numel(cfg.data);F=cfg.stateDimension;timer=tic;
features=reshape(permute(single(ofdm.complexToFeatures(online.pilotObservation)),[1 3 2]),K*F,N);variance=max(mean(double(features).^2,2),1e-5);Q=max(1-online.rho^2,1e-8).*variance;Rpilot=max(online.noiseVar/2,1e-8);
state=double(features(:,1));P=zeros(K,F,F);for k=1:K,index=k+(0:F-1)*K;P(k,:,:)=diag(variance(index)+Rpilot);end
Hhat=complex(zeros(K,N,2,2,'single'));Hhat(:,1,:,:)=online.pilotObservation(:,1,:,:);audit=localAudit(D*N);if options.bypassCapture,capture=localBypass(D,N);end
for n=1:N
    if n>1
        for k=1:K,index=k+(0:F-1)*K;prior=squeeze(P(k,:,:));predicted=online.rho*state(index);predictedP=online.rho^2*prior+diag(Q(index));gain=predictedP/(predictedP+Rpilot*eye(F));state(index)=predicted+gain*(double(features(index,n))-predicted);A=eye(F)-gain;post=A*predictedP*A'+gain*(Rpilot*eye(F))*gain';P(k,:,:)=(post+post')/2;end
        Hhat(:,n,:,:)=ofdm.featuresToComplex(permute(reshape(single(state),K,F),[1 3 2]));audit.pilotUpdateCount=audit.pilotUpdateCount+D;
    end
    if options.bypassCapture,capture.captureSymbolIndex(:,n)=n;capture.captureSubcarrierIndex(:,n)=cfg.data(:);for target=1:D,subcarrier=cfg.data(target);capture.HhatPilotFrozen{target,n}=Hhat(subcarrier,n,:,:);capture.PrealPilotFrozen{target,n}=squeeze(P(subcarrier,:,:));end,end
    if method=="BaseKalmanCausal_EP",continue;end
    frozen=Hhat(:,n,:,:);[X,L]=localDecisions(frozen,online.receivedData(:,n,:),cfg);Y=squeeze(online.receivedData(:,n,:)).';pilotState=state;pilotCovariance=P;
    for target=1:D
        if ~online.validDataMask(target,n),continue;end
        subcarrier=cfg.data(target);index=subcarrier+(0:F-1)*K;hPilot=pilotState(index);PPilot=squeeze(pilotCovariance(subcarrier,:,:));
        [selection,mechanismAudit,reasons]=localSelection(method,X,Y,L,target,online.validDataMask(:,n),hPilot,PPilot,Rpilot,cfg);
        if options.bypassCapture,capture.stream{target,n}=1:2;capture.subcarrier{target,n}=cfg.data(target);capture.symbol{target,n}=n;capture.paddingMask{target,n}=~online.validDataMask(:,n);capture.validDataMask{target,n}=online.validDataMask(:,n);capture.reliabilityMask{target,n}=squeeze(min(min(L,[],1),[],2))>0;capture.candidateMask{target,n}=~mechanismAudit.hardRejected;capture.selectedCandidateMask{target,n}=selection.accepted;end
        audit=localReasons(audit,reasons);
        if mechanismAudit.hardRejected,audit.noCandidateCount=audit.noCandidateCount+1;continue;end
        if ~selection.accepted,audit.noCandidateCount=audit.noCandidateCount+1;continue;end
        state(index)=mechanismAudit.hFinal;P(subcarrier,:,:)=mechanismAudit.PFinal;Hhat(subcarrier,n,:,:)=auditFeatureVectorToChannelMatrix(mechanismAudit.hFinal);audit.daUpdateCount=audit.daUpdateCount+mechanismAudit.updateCount;
        audit=localScalars(audit,mechanismAudit,selection);
    end
end
result=struct('Hhat',Hhat,'onlineEstimationRuntimeSeconds',toc(timer),'audit',localFinalize(audit), ...
    'futureSymbolReadCount',0,'testTruthOnlineUseCount',0,'finalState',state,'finalCovariance',P);if options.bypassCapture,result.bypassCapture=capture;end
end

function c=localBypass(D,N)
fields={'HhatPilotFrozen','PrealPilotFrozen','stream','subcarrier','symbol','paddingMask','validDataMask','reliabilityMask','candidateMask','selectedCandidateMask'};c=struct();for i=1:numel(fields),c.(fields{i})=cell(D,N);end;c.captureSymbolIndex=zeros(D,N);c.captureSubcarrierIndex=zeros(D,N);
end

function [X,L]=localDecisions(Hseed,ySlice,cfg)
D=numel(cfg.data);X=complex(zeros(2,D));L=zeros(4,2,D);for d=1:D,xeq=ofdm.mmseEqualize2x2(double(reshape(ySlice(d,1,:),2,1)),double(squeeze(Hseed(cfg.data(d),1,:,:))),cfg.noiseVar);bits=ofdm.qam16DemodBits(xeq);X(:,d)=ofdm.qam16ModBits(double(bits));L(:,:,d)=reshape(abs(ofdm.qam16DemodLlr(xeq,cfg.noiseVar)),4,2);end
end
function [selection,m,reasons]=localSelection(method,X,Y,L,target,valid,h,P,Rpilot,cfg)
selection=struct('accepted',false,'candidate',[],'selectedRadius',NaN);m=struct('hardRejected',false,'hFinal',h,'PFinal',P,'updateCount',0,'nis',NaN,'nisInflationFactor',NaN,'decisionInflationFactor',NaN,'Rda',[]);reasons=struct('reason',"",'radius',3);
if method=="QualityWindowOnlyCausal_EP"||method=="QualityAwareLocalDAKalmanCausal_EP"
    candidates=repmat(auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,1,h,P,cfg.noiseVar,cfg),1,3);reasons=repmat(struct('reason',"",'radius',1),1,3);for radius=1:3,candidates(radius)=auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,radius,h,P,cfg.noiseVar,cfg);reasons(radius)=struct('reason',string(candidates(radius).rejectReason),'radius',radius);end;selection=auditSelectQualityAwareWindow(candidates,cfg);
    if ~selection.accepted,return;end
    if method=="QualityWindowOnlyCausal_EP",R=Rpilot*eye(8);else,R=selection.candidate.Rda;end
    [m.hFinal,m.PFinal,update]=auditQualityAwareDaKalmanUpdate(h,P,selection,R,cfg);m.updateCount=update.daUpdateCount;m.Rda=R;m.nis=selection.candidate.nis;m.nisInflationFactor=selection.candidate.nisInflationFactor;m.decisionInflationFactor=selection.candidate.decisionInflationFactor;return;
end
reliability=squeeze(min(min(L,[],1),[],2));legacy=auditBuildFixedRadiusLegacyObservation(X,Y,target,valid,reliability,3,cfg);if ~legacy.accepted,reasons.reason=string(legacy.rejectionReason);return;end
variant=localVariant(method);Rlegacy=Rpilot*eye(8);selection.accepted=true;selection.selectedRadius=3;
if any(variant==["A","B","C"])
    selection.candidate=struct('zDa',legacy.feature,'Rda',Rlegacy);
    m=auditMechanismFixedR3Update(h,P,legacy.feature,Rlegacy,[],[],variant,cfg);if m.hardRejected,reasons.reason="innovation_hard_rejection";end;return;
end
if any(variant==["D","E","F"])
    indices=legacy.sampleIndices;ls=auditEstimateLocalLsObservationCovariance(X(:,indices),Y(:,indices),legacy.H,cfg.noiseVar,cfg);
    selection.candidate=struct('zDa',legacy.feature,'Rda',ls.Rls,'Rls',ls.Rls,'mappingAudit',ls.mappingAudit);
    m=auditMechanismFixedR3Update(h,P,legacy.feature,[],ls.Rls,[],variant,cfg);if m.hardRejected,reasons.reason="innovation_hard_rejection";end;return;
end
quality=auditBuildQualityAwareLocalDaCandidate(X,Y,L,target,valid,3,h,P,cfg.noiseVar,cfg);if isempty(quality.Rls),selection.accepted=false;reasons.reason=string(quality.rejectReason);return;end
selection.candidate=quality;
if variant=="G"
    if quality.rejectedByInnovation,m.hardRejected=true;m.nis=quality.nis;reasons.reason="innovation_hard_rejection";return;end
    [m.hFinal,m.PFinal,update]=auditQualityAwareDaKalmanUpdate(h,P,selection,quality.Rda,cfg);m.updateCount=update.daUpdateCount;m.Rda=quality.Rda;m.nis=quality.nis;m.nisInflationFactor=quality.nisInflationFactor;m.decisionInflationFactor=quality.decisionInflationFactor;
else
    m=auditMechanismFixedR3Update(h,P,legacy.feature,Rlegacy,quality.Rls,quality.Rda,variant,cfg);m.decisionInflationFactor=1;
end
end
function variant=localVariant(method)
names=["FixedRadius3Causal_EP","FixedRadius3LegacyHardRejectCausal_EP","FixedRadius3LegacyNisInflationCausal_EP","FixedRadius3LsCovOnlyCausal_EP","CovarianceAwareLocalDAKalmanCausal_EP","FixedRadius3LsCovHardRejectCausal_EP","FixedRadius3LsCovNisInflationCausal_EP","FixedRadius3FullAdaptiveRdaCausal_EP"];variants=["A","B","C","D","D","E","F","G"];index=find(names==method,1);assert(~isempty(index),'Unknown mechanism method %s.',method);variant=variants(index);
end
function a=localAudit(count),zerosByRadius=zeros(1,3);a=struct('candidateFeasibleCount',0,'daUpdateCount',0,'noCandidateCount',0,'innovationHardRejectedCount',0,'insufficientSampleCount',0,'llrGateRejectedCount',0,'gramRankRejectedCount',0,'gramRcondRejectedCount',0,'nonfiniteCandidateCount',0,'covarianceRejectedCount',0,'solverFailureCount',0,'acceptedCandidateCount',0,'pilotUpdateCount',0,'insufficientSampleCountByRadius',zerosByRadius,'llrGateRejectedCountByRadius',zerosByRadius,'gramRankRejectedCountByRadius',zerosByRadius,'gramRcondRejectedCountByRadius',zerosByRadius,'nonfiniteCandidateCountByRadius',zerosByRadius,'innovationHardRejectedCountByRadius',zerosByRadius,'covarianceRejectedCountByRadius',zerosByRadius,'solverFailureCountByRadius',zerosByRadius,'acceptedCandidateCountByRadius',zerosByRadius,'rdaTrace',nan(count,1),'minRlsEigenvalue',nan(count,1),'rlsConditionNumber',nan(count,1),'nis',nan(count,1),'nisInflation',nan(count,1),'decisionInflation',nan(count,1),'cursor',0);end
function a=localReasons(a,reasons)
for index=1:numel(reasons),r=reasons(index);radius=r.radius;switch r.reason,case "",a.candidateFeasibleCount=a.candidateFeasibleCount+1;a.acceptedCandidateCount=a.acceptedCandidateCount+1;a.acceptedCandidateCountByRadius(radius)=a.acceptedCandidateCountByRadius(radius)+1;case "innovation_hard_rejection",a.candidateFeasibleCount=a.candidateFeasibleCount+1;a.innovationHardRejectedCount=a.innovationHardRejectedCount+1;a.innovationHardRejectedCountByRadius(radius)=a.innovationHardRejectedCountByRadius(radius)+1;case "insufficient_samples",a.insufficientSampleCount=a.insufficientSampleCount+1;a.insufficientSampleCountByRadius(radius)=a.insufficientSampleCountByRadius(radius)+1;case "llr_failure",a.llrGateRejectedCount=a.llrGateRejectedCount+1;a.llrGateRejectedCountByRadius(radius)=a.llrGateRejectedCountByRadius(radius)+1;case "rank_failure",a.gramRankRejectedCount=a.gramRankRejectedCount+1;a.gramRankRejectedCountByRadius(radius)=a.gramRankRejectedCountByRadius(radius)+1;case "gram_condition_failure",a.gramRcondRejectedCount=a.gramRcondRejectedCount+1;a.gramRcondRejectedCountByRadius(radius)=a.gramRcondRejectedCountByRadius(radius)+1;case {"numerical_failure","no_quality_candidate"},a.nonfiniteCandidateCount=a.nonfiniteCandidateCount+1;a.nonfiniteCandidateCountByRadius(radius)=a.nonfiniteCandidateCountByRadius(radius)+1;end,end
end
function a=localScalars(a,m,selection),a.cursor=a.cursor+1;c=a.cursor;if ~isempty(m.Rda),a.rdaTrace(c)=trace(m.Rda);end;a.nis(c)=m.nis;a.nisInflation(c)=m.nisInflationFactor;a.decisionInflation(c)=m.decisionInflationFactor;if isfield(selection,'candidate')&&~isempty(selection.candidate)&&isfield(selection.candidate,'mappingAudit'),map=selection.candidate.mappingAudit;a.minRlsEigenvalue(c)=map.minEigenvalueAfterFloor;a.rlsConditionNumber(c)=map.conditionRls;if map.minEigenvalueAfterFloor<-1e-10,a.covarianceRejectedCount=a.covarianceRejectedCount+1;end,end,end
function a=localFinalize(a),names={'rdaTrace','minRlsEigenvalue','rlsConditionNumber','nis','nisInflation','decisionInflation'};for i=1:numel(names),a.(names{i})=a.(names{i})(1:a.cursor);end,end
