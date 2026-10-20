function [Rreal,audit] = auditMapComplexCovarianceToRealState(Ccomplex,cfg)
%AUDITMAPCOMPLEXCOVARIANCETOREALSTATE Map proper complex vec(H) covariance.
% Complex order is [H11 H21 H12 H22]; real order is Re(vec), Im(vec).
assert(ismatrix(Ccomplex)&&size(Ccomplex,1)==size(Ccomplex,2),'Complex covariance must be square.');
n=size(Ccomplex,1);assert(2*n==cfg.stateDimension,'Complex covariance has the wrong state dimension.');
Rreal=.5*[real(Ccomplex),-imag(Ccomplex);imag(Ccomplex),real(Ccomplex)];
Rreal=(Rreal+Rreal')/2;
[V,D]=eig(Rreal,'vector');before=min(real(D));scale=real(trace(Rreal))/cfg.stateDimension;
floorValue=max(cfg.absoluteEigenFloor,cfg.relativeEigenFloor*scale);
D=max(real(D),floorValue);Rreal=real(V*diag(D)*V');Rreal=(Rreal+Rreal')/2;
after=min(real(eig(Rreal)));audit=struct('minEigenvalueBeforeFloor',before, ...
    'minEigenvalueAfterFloor',after,'eigenFloorApplied',before<floorValue, ...
    'eigenFloorValue',floorValue,'traceRls',trace(Rreal),'conditionRls',cond(Rreal));
assert(all(isfinite(Rreal(:)))&&norm(Rreal-Rreal','fro')<=1e-10*max(norm(Rreal,'fro'),1));
end
