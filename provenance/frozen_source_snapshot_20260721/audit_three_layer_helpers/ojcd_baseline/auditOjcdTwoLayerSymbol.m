function result = auditOjcdTwoLayerSymbol(y, pilotCfr, covariance, noiseVar, constellation, options)
%AUDITOJCDTWOLAYERSYMBOL Traditional JCD-1 -> EP -> OJCD JCD-2 -> EP.
arguments
    y (:,:) double
    pilotCfr cell
    covariance struct
    noiseVar (1,1) double
    constellation (:,1) double
    options.epIterations (1,1) double = 5
    options.epBeta (1,1) double = .2
    options.symbolMagnitudeFloor (1,1) double = 1e-4
    options.validDataMask (:,1) logical = true(size(y,1),1)
    options.auditConditionNumbers (1,1) logical = true
    options.forceNegativePrecisionIterationJcd1 (1,1) double = 0
    options.forceNegativePrecisionIterationJcd2 (1,1) double = 0
end
traditional=auditTraditionalLmmseEp(pilotCfr,covariance,noiseVar);
[D,~]=size(y); nt=size(traditional.Hdata,3);
validMask=options.validDataMask(:);assert(numel(validMask)==D,'validDataMask length mismatch.');
xhat=complex(zeros(D,nt)); variance=zeros(D,nt); llr1=zeros(D,nt,4);
rollback1=0;candidate1=0;candidateByIteration1=zeros(options.epIterations,1);rollbackByIteration1=zeros(options.epIterations,1);candidateByStream1=zeros(nt,1);rollbackByStream1=zeros(nt,1);candidateMatrix1=zeros(options.epIterations,nt);rollbackMatrix1=zeros(options.epIterations,nt);
for k=find(validMask).'
    ep=auditEpDetectorOjcd(y(k,:).',squeeze(traditional.Hdata(k,:,:)),noiseVar,constellation, ...
        T=options.epIterations,beta=options.epBeta,forceNegativePrecisionIteration=options.forceNegativePrecisionIterationJcd1);
    xhat(k,:)=ep.posteriorMean.'; variance(k,:)=ep.posteriorVariance.';
    llr1(k,:,:)=ep.bitLlr; rollback1=rollback1+ep.negativePrecisionRollbackCount;
    candidate1=candidate1+ep.precisionCandidateCount;candidateByIteration1=candidateByIteration1+ep.precisionCandidateCountByIteration;rollbackByIteration1=rollbackByIteration1+ep.negativePrecisionRollbackCountByIteration;candidateByStream1=candidateByStream1+ep.precisionCandidateCountByStream;rollbackByStream1=rollbackByStream1+ep.negativePrecisionRollbackCountByStream;
    candidateMatrix1=candidateMatrix1+double(ep.precisionCandidateMatrix);rollbackMatrix1=rollbackMatrix1+double(ep.negativeRollbackMatrix);
end
validIndices=find(validMask);subset=subsetCovariance(covariance,validIndices);
ojcdSubset=auditOjcdLmmseEpAdapted(y(validIndices,:),traditional.Hdata(validIndices,:,:),xhat(validIndices,:),variance(validIndices,:),subset,noiseVar, ...
    symbolMagnitudeFloor=options.symbolMagnitudeFloor,auditConditionNumbers=options.auditConditionNumbers);
ojcd=ojcdSubset;ojcd.Hdata=traditional.Hdata;ojcd.Hdata(validIndices,:,:)=ojcdSubset.Hdata;
llr2=zeros(D,nt,4); posterior2=complex(zeros(D,nt)); variance2=zeros(D,nt);rollback2=0;candidate2=0;candidateByIteration2=zeros(options.epIterations,1);rollbackByIteration2=zeros(options.epIterations,1);candidateByStream2=zeros(nt,1);rollbackByStream2=zeros(nt,1);candidateMatrix2=zeros(options.epIterations,nt);rollbackMatrix2=zeros(options.epIterations,nt);
for k=validIndices.'
    ep=auditEpDetectorOjcd(y(k,:).',squeeze(ojcd.Hdata(k,:,:)),noiseVar,constellation, ...
        T=options.epIterations,beta=options.epBeta,forceNegativePrecisionIteration=options.forceNegativePrecisionIterationJcd2);
    posterior2(k,:)=ep.posteriorMean.';variance2(k,:)=ep.posteriorVariance.';
    llr2(k,:,:)=ep.bitLlr;rollback2=rollback2+ep.negativePrecisionRollbackCount;
    candidate2=candidate2+ep.precisionCandidateCount;candidateByIteration2=candidateByIteration2+ep.precisionCandidateCountByIteration;rollbackByIteration2=rollbackByIteration2+ep.negativePrecisionRollbackCountByIteration;candidateByStream2=candidateByStream2+ep.precisionCandidateCountByStream;rollbackByStream2=rollbackByStream2+ep.negativePrecisionRollbackCountByStream;
    candidateMatrix2=candidateMatrix2+double(ep.precisionCandidateMatrix);rollbackMatrix2=rollbackMatrix2+double(ep.negativeRollbackMatrix);
end
result=struct('traditional',traditional,'ojcd',ojcd,'jcd1PosteriorMean',xhat, ...
    'jcd1PosteriorVariance',variance,'jcd1ExtrinsicLlr',llr1, ...
    'jcd2PosteriorMean',posterior2,'jcd2PosteriorVariance',variance2, ...
    'finalExtrinsicLlr',llr2,'negativePrecisionRollbackCount',rollback1+rollback2, ...
    'epPrecisionCandidateCountJcd1',candidate1,'epNegativePrecisionRollbackCountJcd1',rollback1, ...
    'epPrecisionCandidateCountJcd2',candidate2,'epNegativePrecisionRollbackCountJcd2',rollback2, ...
    'precisionCandidateCountByIterationJcd1',candidateByIteration1,'rollbackCountByIterationJcd1',rollbackByIteration1, ...
    'precisionCandidateCountByIterationJcd2',candidateByIteration2,'rollbackCountByIterationJcd2',rollbackByIteration2, ...
    'precisionCandidateCountByStreamJcd1',candidateByStream1,'rollbackCountByStreamJcd1',rollbackByStream1, ...
    'precisionCandidateCountByStreamJcd2',candidateByStream2,'rollbackCountByStreamJcd2',rollbackByStream2, ...
    'precisionCandidateCountByIterationStreamJcd1',candidateMatrix1,'rollbackCountByIterationStreamJcd1',rollbackMatrix1, ...
    'precisionCandidateCountByIterationStreamJcd2',candidateMatrix2,'rollbackCountByIterationStreamJcd2',rollbackMatrix2);
end

function subset=subsetCovariance(covariance,indices)
subset=covariance;nt=size(covariance.Rhdhd,1);
for a=1:nt
    subset.Wtraditional{a}=covariance.Wtraditional{a}(indices,:);
    for b=1:nt
        subset.Rhdhd{a,b}=covariance.Rhdhd{a,b}(indices,indices);
        subset.Rhdhp{a,b}=covariance.Rhdhp{a,b}(indices,:);
    end
end
end
