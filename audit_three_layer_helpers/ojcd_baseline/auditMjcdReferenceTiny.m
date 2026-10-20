function out = auditMjcdReferenceTiny(y, xhat, symbolVariance, Chh, noiseVar)
%AUDITMJCDREFERENCETINY Direct large-matrix MJCD-LMMSE, equation (18).
% This deterministic reference is intentionally unsuitable for packet runs.
[D,nr]=size(y);nt=size(xhat,2); assert(isequal(size(Chh),[nr*nt*D nr*nt*D]));
xvec=reshape(xhat,D*nt,1);vvec=reshape(symbolVariance,D*nt,1);
Xone=kron(ones(1,nt),eye(D))*diag(xvec);
X=kron(eye(nr),Xone);
A=kron(eye(nr),kron(ones(1,nt),eye(D)));
V=diag(vvec);
B=Chh.*kron(ones(nr),V);
Cyy=X*Chh*X'+A*B*A'+noiseVar*eye(nr*D);
Cyy=(Cyy+Cyy')/2;
hhat=Chh*X'/Cyy*reshape(y,D*nr,1);
out=struct('hhatVector',hhat,'Hdata',permute(reshape(hhat,D,nt,nr),[1 3 2]), ...
    'Cyy',Cyy,'minimumRcond',rcond(Cyy),'hasNaN',any(isnan(hhat)), ...
    'hasInf',any(isinf(hhat)));
end
