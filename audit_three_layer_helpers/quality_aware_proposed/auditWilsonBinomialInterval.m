function [lower,upper]=auditWilsonBinomialInterval(errorCount,totalCount,confidence)
%AUDITWILSONBINOMIALINTERVAL Wilson score interval for a binomial error rate.
if nargin<3,confidence=.95;end
assert(totalCount>0&&errorCount>=0&&errorCount<=totalCount);assert(abs(confidence-.95)<eps,'Only the frozen 95%% interval is supported.');
z=1.959963984540054;p=errorCount/totalCount;den=1+z^2/totalCount;
center=(p+z^2/(2*totalCount))/den;half=z*sqrt(p*(1-p)/totalCount+z^2/(4*totalCount^2))/den;
lower=max(0,center-half);upper=min(1,center+half);
end

