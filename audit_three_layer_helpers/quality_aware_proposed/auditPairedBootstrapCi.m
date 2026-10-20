function result = auditPairedBootstrapCi(delta,seed,replicates)
%AUDITPAIREDBOOTSTRAPCI Deterministic paired mean bootstrap without toolbox.
if nargin<3,replicates=5000;end;delta=delta(isfinite(delta));assert(numel(delta)>=1&&replicates>=1);state=rng;rng(seed,'twister');cleanup=onCleanup(@()rng(state));n=numel(delta);means=zeros(replicates,1);for index=1:replicates,means(index)=mean(delta(randi(n,n,1)));end
result=struct('pointEstimate',mean(delta),'ciLower95',auditDeterministicPercentile(means,.025),'ciUpper95',auditDeterministicPercentile(means,.975),'replicates',replicates,'seed',seed);
end
