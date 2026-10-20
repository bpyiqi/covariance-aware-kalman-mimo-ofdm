function [mu,Vx,Sx,diagOut] = ucDecisionMomentsFromDiscretePosterior(q,constellation)
if size(q,2)~=numel(constellation), error('q columns must match constellation.'); end
rowSum=sum(q,2);
if any(~isfinite(q(:))) || any(abs(rowSum-1)>1e-12), error('Each q row must be normalized.'); end
c=reshape(constellation,1,[]); mu=q*c.';
v=sum(q.*abs(c-mu).^2,2);
if any(v < -1e-13), error('Posterior variance is materially negative.'); end
v(v<0)=0; Vx=diag(v); Sx=Vx+mu*mu';
diagOut=struct('minVariance',min(v),'factorizedApproximation',true);
end
