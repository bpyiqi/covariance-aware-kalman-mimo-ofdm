function out = auditScoreQualityAwareCandidate(PPilot,Rda,cfg)
%AUDITSCOREQUALITYAWARECANDIDATE Hypothetical Joseph posterior trace score.
d=cfg.stateDimension;I=eye(d);K=PPilot/(PPilot+Rda);A=I-K;
Ppost=A*PPilot*A'+K*Rda*K';Ppost=(Ppost+Ppost')/2;
score=trace(Ppost)/max(trace(PPilot),eps);
out=struct('kalmanGain',K,'posteriorCovariance',Ppost,'qualityScore',score);
assert(isfinite(score)&&all(isfinite(Ppost(:))));
end
