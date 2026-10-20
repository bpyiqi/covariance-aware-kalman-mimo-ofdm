function post = auditEpConstellationPosterior(extrinsicMean, extrinsicVariance, constellation, options)
%AUDITEPCONSTELLATIONPOSTERIOR Stable discrete posterior for EP equation (12).

arguments
    extrinsicMean (:,1) double
    extrinsicVariance (:,1) double
    constellation (:,1) double
    options.varianceFloor (1,1) double = 1e-12
    options.probabilityFloor (1,1) double = realmin('double')
end

variance = max(real(extrinsicVariance), options.varianceFloor);
distance = abs(extrinsicMean - constellation.').^2;
logWeight = -distance ./ variance;
logWeight = logWeight - max(logWeight, [], 2);
weight = exp(logWeight);
probability = weight ./ max(sum(weight, 2), options.probabilityFloor);

meanValue = probability * constellation;
secondMoment = probability * abs(constellation).^2;
varianceValue = max(real(secondMoment - abs(meanValue).^2), options.varianceFloor);

post = struct('mean',meanValue,'variance',varianceValue, ...
    'probability',probability,'probabilitySum',sum(probability,2), ...
    'hasNaN',any(isnan(probability(:))),'hasInf',any(isinf(probability(:))));
end
