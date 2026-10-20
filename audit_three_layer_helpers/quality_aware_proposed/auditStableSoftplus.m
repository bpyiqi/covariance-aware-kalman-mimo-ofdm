function y=auditStableSoftplus(x)
%AUDITSTABLESOFTPLUS Numerically stable log(1+exp(x)).
y=max(x,0)+log1p(exp(-abs(x)));
end

