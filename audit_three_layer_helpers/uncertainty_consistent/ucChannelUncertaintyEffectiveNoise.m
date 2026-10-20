function [Reff,Rcsi,diagOut] = ucChannelUncertaintyEffectiveNoise(Rn,Ph,mx,Vx,Nr,Nt)
Sx=Vx+mx*mx'; Rcsi=ucChannelCovarianceContraction(Ph,Sx,Nr,Nt);
[Rcsi,cdiag]=ucProjectHermitianPsd(Rcsi); Reff=(Rn+Rcsi); Reff=(Reff+Reff')/2;
mineig=min(real(eig(Reff)));
if mineig<=0, error('Effective noise covariance is not positive definite.'); end
diagOut=struct('traceRcsi',real(trace(Rcsi)),'traceRn',real(trace(Rn)), ...
    'csiToNoiseRatio',real(trace(Rcsi))/max(real(trace(Rn)),eps), ...
    'minEigenvalueRcsi',cdiag.minEigenvalueBefore,'minEigenvalueReff',mineig);
end
