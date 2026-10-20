function [Ph,Ppseudo,diagOut] = ucRealStateCovToComplex(Preal)
% State order: Re(H11,H21,H12,H22), Im(H11,H21,H12,H22).
[nr,nc]=size(Preal);
if nr~=nc || mod(nr,2)~=0, error('Preal must be square with even size.'); end
d=nr/2;
PRR=Preal(1:d,1:d); PRI=Preal(1:d,d+1:end);
PIR=Preal(d+1:end,1:d); PII=Preal(d+1:end,d+1:end);
Ph=PRR+PII+1i*(PIR-PRI);
Ppseudo=PRR-PII+1i*(PRI+PIR);
Ph=(Ph+Ph')/2;
diagOut=struct('propernessRatio',norm(Ppseudo,'fro')/max(norm(Ph,'fro'),eps), ...
    'availability','proper_approximation_only','stateOrder', ...
    'Re(H11),Re(H21),Re(H12),Re(H22),Im(H11),Im(H21),Im(H12),Im(H22)');
end
