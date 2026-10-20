function out = auditComputeInnovationConsistency(hPilot,PPilot,zDa,Rdecision,cfg)
%AUDITCOMPUTEINNOVATIONCONSISTENCY NIS inflation and fixed dof-8 rejection.
hPilot=hPilot(:);zDa=zDa(:);assert(numel(hPilot)==cfg.stateDimension&&numel(zDa)==cfg.stateDimension);
S=(PPilot+Rdecision);S=(S+S')/2;innovation=zDa-hPilot;
nis=real(innovation'*(S\innovation));normalizedNis=nis/cfg.stateDimension;
alphaNis=max(1,normalizedNis);Rda=alphaNis*Rdecision;
out=struct('innovation',innovation,'innovationNorm',norm(innovation),'nis',nis, ...
    'normalizedNis',normalizedNis,'nisInflationFactor',alphaNis,'Rda',Rda, ...
    'rejectedByInnovation',nis>cfg.chiSquareHardThresholdDof8P999);
assert(isfinite(nis)&&all(isfinite(Rda(:))));
end
