function out = auditComputeDecisionReliabilityInflation(absLlr,cfg)
%AUDITCOMPUTEDECISIONRELIABILITYINFLATION Convert used bit LLRs to inflation.
% absLlr is bits-per-QAM by stream by local-sample; all entries are used.
assert(~isempty(absLlr)&&all(isfinite(absLlr(:)))&&all(absLlr(:)>=0));
clipped=min(absLlr,cfg.llrClip);bitError=1./(1+exp(clipped));
symbolCorrect=squeeze(prod(1-bitError,1));qDecision=mean(symbolCorrect(:));
qDecision=min(1,max(cfg.qDecisionFloor,qDecision));
alphaDecision=min(cfg.alphaDecisionMax,1/qDecision);
out=struct('meanDecisionCorrectProbability',qDecision, ...
    'decisionInflationFactor',alphaDecision, ...
    'minimumUsedAbsLlr',min(absLlr(:)),'medianUsedAbsLlr',median(absLlr(:)), ...
    'meanUsedAbsLlr',mean(absLlr(:)),'bitErrorProbability',bitError);
end
