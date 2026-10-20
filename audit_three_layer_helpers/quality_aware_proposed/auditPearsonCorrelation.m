function value = auditPearsonCorrelation(x,y)
%AUDITPEARSONCORRELATION Pairwise finite Pearson coefficient.
mask=isfinite(x)&isfinite(y);x=x(mask);y=y(mask);if numel(x)<3||max(x)==min(x)||max(y)==min(y),value=NaN;return;end
x=x-mean(x);y=y-mean(y);value=sum(x.*y)/sqrt(sum(x.^2)*sum(y.^2));
end
