function out = auditEstimateLocalLsObservationCovariance(X,Y,Hls,noiseVar,cfg)
%AUDITESTIMATELOCALLSOBSERVATIONCOVARIANCE Residual-based local-LS R_LS.
% X is Nt-by-M, Y is Nr-by-M, and Hls is Nr-by-Nt for one OFDM symbol.
assert(size(X,1)==cfg.Nt&&size(Y,1)==cfg.Nr&&size(X,2)==size(Y,2));
assert(all(isfinite(X(:)))&&all(isfinite(Y(:)))&&all(isfinite(Hls(:))));
M=size(X,2);G=X*X';G=(G+G')/2;gramRcond=rcond(G);
assert(rank(G)==cfg.Nt&&isfinite(gramRcond)&&gramRcond>=cfg.gramRcondThreshold);
E=Y-Hls*X;energy=sum(abs(E(:)).^2);normalizedResidual=energy/max(sum(abs(Y(:)).^2),eps);
dof=cfg.Nr*max(M-cfg.Nt,0);if dof>0,sigma2Residual=energy/dof;else,sigma2Residual=noiseVar;end
sigma2Hat=max(noiseVar,real(sigma2Residual));Ginverse=G\eye(cfg.Nt);
Ccomplex=sigma2Hat*kron(Ginverse.',eye(cfg.Nr));
[Rls,mapAudit]=auditMapComplexCovarianceToRealState(Ccomplex,cfg);
out=struct('gram',G,'gramRcond',gramRcond,'residual',E, ...
    'normalizedResidual',normalizedResidual,'sigma2Residual',sigma2Residual, ...
    'sigma2Hat',sigma2Hat,'complexCovariance',Ccomplex,'Rls',Rls, ...
    'effectiveSampleCount',M,'degreesOfFreedom',dof,'mappingAudit',mapAudit);
end
