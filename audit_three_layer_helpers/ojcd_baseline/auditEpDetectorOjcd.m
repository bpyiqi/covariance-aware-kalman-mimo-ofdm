function ep = auditEpDetectorOjcd(y, Hhat, noiseVar, constellation, options)
%AUDITEPDETECTOROJCD Complex MIMO EP detector from Algorithm 1, (10)-(14).
% This online function deliberately has no H_true, true-QAM, or true-bit input.

arguments
    y (:,1) double
    Hhat (:,:) double
    noiseVar (1,1) double {mustBePositive}
    constellation (:,1) double
    options.T (1,1) double = 5
    options.beta (1,1) double = 0.2
    options.varianceFloor (1,1) double = 1e-12
    options.precisionFloor (1,1) double = 1e-12
    options.probabilityFloor (1,1) double = realmin('double')
    options.forceNegativePrecisionIteration (1,1) double = 0
    options.captureDiagnostic (1,1) logical = false
end

[nr, nt] = size(Hhat);
assert(numel(y)==nr && ~isempty(constellation), 'EP input dimensions are inconsistent.');
Es = mean(abs(constellation).^2);
lambda = repmat(max(1/Es,options.precisionFloor),nt,1);
gamma = complex(zeros(nt,1));
rollbackCount = 0;
invalidRollbackCount = 0;
candidateByIteration = zeros(options.T,1);
rollbackByIteration = zeros(options.T,1);
candidateByStream = zeros(nt,1);
rollbackByStream = zeros(nt,1);
candidateMatrix = false(options.T,nt);
rollbackMatrix = false(options.T,nt);
eyeNt = eye(nt);
if options.captureDiagnostic
    diagLast=struct('sigmaDiag',[],'cavityDenominator',[],'extrinsicVariance',[],'extrinsicMean',[], ...
        'posteriorVariance',[],'posteriorMean',[],'varianceUsedForLlr',[],'lambdaBeforeUpdate',[], ...
        'lambdaCandidate',[],'bitLlr',[],'gramRcond',NaN,'precisionFloorHits',0,'varianceFloorHits',0, ...
        'negativePrecisionCandidates',0,'nonfiniteCandidates',0,'rollbackCount',0, ...
        'minimumExtrinsicVariance',NaN,'minimumPosteriorVariance',NaN,'minimumAbsCavityDenominator',NaN);
    precisionFloorHitTotal=0;varianceFloorHitTotal=0;
end

for t = 1:options.T
    % Algorithm 1, equation (10). Hhat' is the conjugate transpose.
    lambdaBeforeUpdate = lambda;
    precision = Hhat' * Hhat / noiseVar + diag(lambda);
    precision = (precision + precision')/2;
    Sigma = precision \ eyeNt;
    Sigma = (Sigma + Sigma')/2;
    mu = Sigma * (Hhat' * y / noiseVar + gamma);
    rawSigmaDiag=real(diag(Sigma));sigmaDiag = max(rawSigmaDiag,options.varianceFloor);

    % Equation (11), component-wise cavity moments.
    denominator = 1 - sigmaDiag .* lambda;
    cavityDenominator=denominator;
    tiny = abs(denominator) < options.precisionFloor;
    denominator(tiny) = sign(real(denominator(tiny)) + eps) * options.precisionFloor;
    Ve = sigmaDiag ./ denominator;
    invalidVe = ~isfinite(Ve) | Ve <= options.varianceFloor;
    Ve(invalidVe) = 1/options.precisionFloor;
    xe = Ve .* (mu ./ sigmaDiag - gamma);

    % Equation (12), evaluated by a log-sum-exp-equivalent normalization.
    post = auditEpConstellationPosterior(xe,Ve,constellation, ...
        varianceFloor=options.varianceFloor,probabilityFloor=options.probabilityFloor);
    Vp = max(post.variance,options.varianceFloor);
    xp = post.mean;

    % Equation (13), with the component-wise negative-precision rollback.
    lambdaCandidate = 1./Vp - 1./Ve;
    gammaCandidate = xp./Vp - xe./Ve;
    if options.forceNegativePrecisionIteration == t
        lambdaCandidate(1) = -abs(lambdaCandidate(1))-1;
    end
    candidateMatrix(t,:) = true(1,nt);
    candidateByIteration(t) = nt;
    candidateByStream = candidateByStream + 1;
    lambdaCandidateRaw=lambdaCandidate;negative = isfinite(lambdaCandidate) & lambdaCandidate < 0;
    invalid = ~isfinite(lambdaCandidate) | ~isfinite(gammaCandidate);
    bad = negative | invalid;
    rollbackMatrix(t,:) = negative.';
    rollbackByIteration(t) = nnz(negative);
    rollbackByStream = rollbackByStream + double(negative);
    rollbackCount = rollbackCount + nnz(negative);
    invalidRollbackCount = invalidRollbackCount + nnz(invalid);
    lambdaCandidate(bad) = lambda(bad);
    gammaCandidate(bad) = gamma(bad);

    % Equation (14), damping is applied after rollback exactly as Algorithm 1.
    lambda = options.beta*lambdaCandidate + (1-options.beta)*lambda;
    gamma = options.beta*gammaCandidate + (1-options.beta)*gamma;
    lambda = max(real(lambda),options.precisionFloor);
    if options.captureDiagnostic
        diagLast.sigmaDiag=sigmaDiag;diagLast.cavityDenominator=cavityDenominator;diagLast.extrinsicVariance=Ve;diagLast.extrinsicMean=xe;
        precisionFloorHitTotal=precisionFloorHitTotal+nnz(rawSigmaDiag<=options.varianceFloor)+nnz(tiny);
        varianceFloorHitTotal=varianceFloorHitTotal+nnz(rawSigmaDiag<=options.varianceFloor)+nnz(post.variance<=options.varianceFloor);
        diagLast.posteriorVariance=Vp;diagLast.posteriorMean=xp;diagLast.lambdaBeforeUpdate=lambdaBeforeUpdate;diagLast.lambdaCandidate=lambdaCandidateRaw;
        diagLast.gramRcond=rcond(precision);diagLast.precisionFloorHits=precisionFloorHitTotal;
        diagLast.varianceFloorHits=varianceFloorHitTotal;
        diagLast.negativePrecisionCandidates=rollbackCount;diagLast.nonfiniteCandidates=invalidRollbackCount;diagLast.rollbackCount=rollbackCount+invalidRollbackCount;
        diagLast.minimumExtrinsicVariance=min(Ve);diagLast.minimumPosteriorVariance=min(Vp);diagLast.minimumAbsCavityDenominator=min(abs(cavityDenominator));
    end
end

[~,hardIndex] = min(abs(xp-constellation.'),[],2);
hardSymbols = constellation(hardIndex);
labels = reshape(qamdemod(constellation,16,'UnitAveragePower',true, ...
    'OutputType','bit'),4,[]).';
bitLlr = zeros(nt,4);
for bit = 1:4
    p0 = sum(post.probability(:,labels(:,bit)==0),2);
    p1 = sum(post.probability(:,labels(:,bit)==1),2);
    bitLlr(:,bit) = log(max(p0,options.probabilityFloor)) - ...
        log(max(p1,options.probabilityFloor));
end

allValues = [Sigma(:);mu(:);Ve(:);xe(:);xp(:);Vp(:);lambda(:);gamma(:);bitLlr(:)];
ep = struct('posteriorMean',xp,'posteriorVariance',Vp, ...
    'extrinsicMean',xe,'extrinsicVariance',Ve,'hardSymbols',hardSymbols, ...
    'bitLlr',bitLlr,'lambda',lambda,'gamma',gamma, ...
    'precisionCandidateCount',nnz(candidateMatrix), ...
    'negativePrecisionRollbackCount',rollbackCount, ...
    'invalidPrecisionRollbackCount',invalidRollbackCount, ...
    'precisionCandidateCountByIteration',candidateByIteration, ...
    'negativePrecisionRollbackCountByIteration',rollbackByIteration, ...
    'rollbackRateByIteration',safeRate(rollbackByIteration,candidateByIteration), ...
    'precisionCandidateCountByStream',candidateByStream, ...
    'negativePrecisionRollbackCountByStream',rollbackByStream, ...
    'rollbackRateByStream',safeRate(rollbackByStream,candidateByStream), ...
    'precisionCandidateMatrix',candidateMatrix,'negativeRollbackMatrix',rollbackMatrix, ...
    'hasNaN',any(isnan(allValues)),'hasInf',any(isinf(allValues)));
if options.captureDiagnostic
    diagLast.bitLlr=bitLlr;diagLast.varianceUsedForLlr=Vp;
    ep.diagOut=diagLast;
end
end

function rate=safeRate(count,candidate)
rate=zeros(size(count));valid=candidate>0;rate(valid)=count(valid)./candidate(valid);
end
