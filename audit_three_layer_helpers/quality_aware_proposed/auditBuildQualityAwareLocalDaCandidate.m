function candidate = auditBuildQualityAwareLocalDaCandidate(X,Y,absLlr,targetIndex,validMask,radius,hPilot,PPilot,noiseVar,cfg)
%AUDITBUILDQUALITYAWARELOCALDACANDIDATE Build one frozen-seed local candidate.
% Only the current symbol's non-padding, reliable samples may enter X/Y/LLR.
candidate=localEmpty(radius);D=size(X,2);assert(size(Y,2)==D&&numel(validMask)==D&&size(absLlr,3)==D);
indices=max(1,targetIndex-radius):min(D,targetIndex+radius);indices=indices(validMask(indices));
if numel(indices)<cfg.minEffectiveSamples,candidate.rejectReason="insufficient_samples";return;end
sampleReliability=squeeze(min(min(absLlr(:,:,indices),[],1),[],2));
indices=indices(sampleReliability(:).'>=cfg.llrThreshold);
if numel(indices)<cfg.minEffectiveSamples,candidate.rejectReason="llr_failure";return;end
Xi=X(:,indices);Yi=Y(:,indices);candidate.effectiveSampleCount=numel(indices);candidate.sampleIndices=indices;
G=Xi*Xi';candidate.gramRcond=rcond(G);
if rank(G)<cfg.Nt,candidate.rejectReason="rank_failure";return;end
if ~isfinite(candidate.gramRcond)||candidate.gramRcond<cfg.gramRcondThreshold,candidate.rejectReason="gram_condition_failure";return;end
Hls=(Yi*Xi')/G;if any(~isfinite(Hls(:))),candidate.rejectReason="numerical_failure";return;end
ls=auditEstimateLocalLsObservationCovariance(Xi,Yi,Hls,noiseVar,cfg);
decision=auditComputeDecisionReliabilityInflation(absLlr(:,:,indices),cfg);
Rdecision=decision.decisionInflationFactor*ls.Rls;z=auditChannelMatrixToFeatureVector(Hls);
innovation=auditComputeInnovationConsistency(hPilot,PPilot,z,Rdecision,cfg);
candidate=localMerge(candidate,ls,decision,innovation,Hls,z);
if innovation.rejectedByInnovation,candidate.rejectReason="innovation_hard_rejection";return;end
score=auditScoreQualityAwareCandidate(PPilot,innovation.Rda,cfg);
candidate.candidateFeasible=true;candidate.rejectReason="";candidate.qualityScore=score.qualityScore;
candidate.hypotheticalPosteriorCovariance=score.posteriorCovariance;
end

function c=localEmpty(radius)
c=struct('radius',radius,'candidateFeasible',false,'rejectReason',"not_evaluated", ...
    'effectiveSampleCount',0,'sampleIndices',[],'gramRcond',NaN, ...
    'normalizedResidual',NaN,'sigma2Residual',NaN,'sigma2Hat',NaN, ...
    'Rls',[],'Rdecision',[],'Rda',[],'Hda',[],'zDa',[],'qualityScore',Inf, ...
    'meanDecisionCorrectProbability',NaN,'decisionInflationFactor',NaN, ...
    'minimumUsedAbsLlr',NaN,'medianUsedAbsLlr',NaN,'meanUsedAbsLlr',NaN, ...
    'innovationNorm',NaN,'nis',NaN,'normalizedNis',NaN,'nisInflationFactor',NaN, ...
    'rejectedByInnovation',false,'mappingAudit',struct(),'hypotheticalPosteriorCovariance',[]);
end
function c=localMerge(c,ls,d,i,H,z)
c.normalizedResidual=ls.normalizedResidual;c.sigma2Residual=ls.sigma2Residual;c.sigma2Hat=ls.sigma2Hat;c.Rls=ls.Rls;c.mappingAudit=ls.mappingAudit;
c.meanDecisionCorrectProbability=d.meanDecisionCorrectProbability;c.decisionInflationFactor=d.decisionInflationFactor;c.minimumUsedAbsLlr=d.minimumUsedAbsLlr;c.medianUsedAbsLlr=d.medianUsedAbsLlr;c.meanUsedAbsLlr=d.meanUsedAbsLlr;c.Rdecision=d.decisionInflationFactor*ls.Rls;
c.innovationNorm=i.innovationNorm;c.nis=i.nis;c.normalizedNis=i.normalizedNis;c.nisInflationFactor=i.nisInflationFactor;c.rejectedByInnovation=i.rejectedByInnovation;c.Rda=i.Rda;c.Hda=H;c.zDa=z;
end
