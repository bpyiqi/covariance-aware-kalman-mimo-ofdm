function value = auditDeterministicPercentile(data,probability)
%AUDITDETERMINISTICPERCENTILE Linear sorted percentile, no toolbox.
data=sort(data(isfinite(data)));if isempty(data),value=NaN;return;end
position=1+(numel(data)-1)*probability;lower=floor(position);upper=ceil(position);value=data(lower)+(position-lower)*(data(upper)-data(lower));
end
