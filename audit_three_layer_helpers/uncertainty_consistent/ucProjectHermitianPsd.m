function [P,diagOut] = ucProjectHermitianPsd(P)
% Symmetrize and correct only roundoff-scale negative eigenvalues.
P=(P+P')/2;
[U,D]=eig(P,'vector');
scale=max(1,norm(P,'fro'));
tol=100*eps(scale);
minBefore=min(real(D));
if minBefore < -tol
    error('ucProjectHermitianPsd:MaterialNegativeEigenvalue', ...
        'PSD violation (%g) is larger than floating-point tolerance.',minBefore);
end
D(real(D)<0)=0;
P=U*diag(real(D))*U';
P=(P+P')/2;
diagOut=struct('minEigenvalueBefore',minBefore,'tolerance',tol, ...
    'repairedRoundoff',minBefore<0);
end
