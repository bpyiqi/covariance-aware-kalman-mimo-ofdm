function summary=auditEpReliabilityAggregate(rows)
%AUDITEPRELIABILITYAGGREGATE Sum sufficient statistics and derive calibration metrics.
keys={'dimension','dimensionValue','method','targetSnrDb'};groups=unique(rows(:,keys),'rows');out=cell(height(groups),1);
for i=1:height(groups)
    x=rows(rows.dimension==groups.dimension(i)&rows.dimensionValue==groups.dimensionValue(i)& ...
        rows.method==groups.method(i)&rows.targetSnrDb==groups.targetSnrDb(i),:);
    count=sum(x.bitCount);errors=sum(x.errorCount);pred=sum(x.predictedErrorProbabilitySum);nll=sum(x.nllSum);brier=sum(x.brierSum);
    empirical=errors/count;meanPred=pred/count;ratio=empirical/max(meanPred,realmin);ece=abs(empirical-meanPred)*count;
    out{i}=table(groups.dimension(i),groups.dimensionValue(i),groups.method(i),groups.targetSnrDb(i),count,errors,empirical,meanPred,ratio, ...
        sum(x.signedMarginSum)/count,sum(x.negativeMarginCount),nll/count,brier/count,ece, ...
        'VariableNames',{'dimension','dimensionValue','method','targetSnrDb','bitCount','errorCount','empiricalErrorRate', ...
        'meanPredictedErrorProbability','calibrationRatio','meanSignedMargin','negativeMarginCount','pooledNll','brierScore','eceRaw'});
end
summary=vertcat(out{:});
for dimension=unique(summary.dimension).'
    indices=summary.dimension==dimension;total=sum(summary.bitCount(indices));summary.eceContribution(indices)=summary.eceRaw(indices)/total;
end
summary.eceRaw=[];
end
