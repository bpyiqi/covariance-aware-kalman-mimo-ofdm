function value = auditSpearmanCorrelation(x,y)
%AUDITSPEARMANCORRELATION Stable average tied ranks then Pearson.
mask=isfinite(x)&isfinite(y);x=x(mask);y=y(mask);if numel(x)<3,value=NaN;return;end
value=auditPearsonCorrelation(localTiedRank(x),localTiedRank(y));
end
function ranks=localTiedRank(values)
[sorted,order]=sort(values,'ascend');ranks=zeros(size(values));index=1;
while index<=numel(values),last=index;while last<numel(values)&&sorted(last+1)==sorted(index),last=last+1;end;ranks(order(index:last))=(index+last)/2;index=last+1;end
end
