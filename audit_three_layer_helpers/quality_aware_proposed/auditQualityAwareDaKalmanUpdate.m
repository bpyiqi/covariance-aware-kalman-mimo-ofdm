function [hFinal,PFinal,audit] = auditQualityAwareDaKalmanUpdate(hPilot,PPilot,selection,Roverride,cfg)
%AUDITQUALITYAWAREDAKALMANUPDATE Apply at most one identity-observation update.
hPilot=hPilot(:);PPilot=(PPilot+PPilot')/2;hFinal=hPilot;PFinal=PPilot;
audit=struct('daUpdateCount',0,'kalmanGain',zeros(cfg.stateDimension), ...
    'updateMagnitude',0,'strictFallback',true);
if ~selection.accepted,return;end
if nargin<4||isempty(Roverride),R=selection.candidate.Rda;else,R=Roverride;end
I=eye(cfg.stateDimension);K=PPilot/(PPilot+R);innovation=selection.candidate.zDa-hPilot;
hFinal=hPilot+K*innovation;A=I-K;PFinal=A*PPilot*A'+K*R*K';PFinal=(PFinal+PFinal')/2;
audit=struct('daUpdateCount',1,'kalmanGain',K,'updateMagnitude',norm(K*innovation),'strictFallback',false);
assert(all(isfinite(hFinal))&&all(isfinite(PFinal(:)))&&min(real(eig(PFinal)))>=-1e-10);
end
