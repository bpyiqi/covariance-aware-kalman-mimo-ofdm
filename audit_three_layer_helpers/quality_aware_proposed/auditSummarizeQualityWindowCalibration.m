function summary = auditSummarizeQualityWindowCalibration(candidateTable,targetTable,tieTolerance)
%AUDITSUMMARIZEQUALITYWINDOWCALIBRATION Aggregate offline selection quality.
valid=targetTable.acceptedCandidateCountAfterInnovation>0&isfinite(targetTable.selectionRegretAbs);multi=valid&targetTable.acceptedCandidateCountAfterInnovation>1;single=valid&targetTable.acceptedCandidateCountAfterInnovation==1;
regret=targetTable.selectionRegretAbs(valid);relative=targetTable.selectionRegretRelative(valid);
[concordant,pairCount]=localPairwise(candidateTable,tieTolerance);
overall=table("overall",NaN,nnz(valid),nnz(multi),nnz(single),localRatio(nnz(targetTable.selectionIsOracleBest&multi),nnz(multi)),localRatio(nnz(regret<=tieTolerance),numel(regret)),localStat(regret,'mean'),localStat(regret,'median'),localPercentile(regret,.90),localPercentile(regret,.95),localStat(regret,'max'),localStat(relative,'mean'),localStat(relative,'median'),localPercentile(relative,.95),localRatio(concordant,pairCount),pairCount,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
    'VariableNames',localNames());
radiusRows=cell(3,1);totalSelected=nnz(candidateTable.selectedByOnlineMethod);totalOracle=nnz(isfinite(targetTable.oracleBestRadiusAfterInnovation));
for radius=1:3
    rows=candidateTable(candidateTable.candidateRadius==radius,:);truth=rows.trueNormalizedError(rows.feasibleBeforeInnovation&isfinite(rows.trueNormalizedError));feasible=nnz(rows.feasibleBeforeInnovation);accepted=nnz(rows.acceptedAfterInnovation);selectedCount=nnz(rows.selectedByOnlineMethod);oracleCount=nnz(targetTable.oracleBestRadiusAfterInnovation==radius);
    radiusRows{radius}=table("radius",radius,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,feasible,accepted,selectedCount,oracleCount,localStat(truth,'mean'),localStat(truth,'median'),localPercentile(truth,.95),localStat(rows.onlineQualityScore(isfinite(rows.onlineQualityScore)),'mean'),localStat(rows.traceRda(isfinite(rows.traceRda)),'mean'),localRatio(selectedCount,totalSelected),localRatio(oracleCount,totalOracle),'VariableNames',localNames());
end
summary=vertcat(overall,radiusRows{:});
end

function names=localNames()
names={'aggregationLevel','radius','validSelectionCount','multiCandidateTargetCount','singleCandidateTargetCount','selectionAccuracy','zeroRegretRate','meanRegretAbs','medianRegretAbs','p90RegretAbs','p95RegretAbs','maximumRegretAbs','meanRegretRelative','medianRegretRelative','p95RegretRelative','pairwiseOrderingAgreement','validPairCount','feasibleCount','acceptedCount','selectedCount','oracleBestCount','meanTrueError','medianTrueError','p95TrueError','meanOnlineScore','meanTraceRda','selectionRate','oracleBestRate'};
end
function [concordant,total]=localPairwise(T,tolerance)
keys=unique(T(:,{'payloadSymbols','packetIndex','symbolIndex','targetIndex'}),'rows');concordant=0;total=0;
for keyIndex=1:height(keys)
    rows=T(T.payloadSymbols==keys.payloadSymbols(keyIndex)&T.packetIndex==keys.packetIndex(keyIndex)&T.symbolIndex==keys.symbolIndex(keyIndex)&T.targetIndex==keys.targetIndex(keyIndex)&T.acceptedAfterInnovation,:);
    for i=1:height(rows)-1,for j=i+1:height(rows),scoreDelta=rows.onlineQualityScore(i)-rows.onlineQualityScore(j);errorDelta=rows.trueNormalizedError(i)-rows.trueNormalizedError(j);if abs(scoreDelta)<=tolerance||abs(errorDelta)<=tolerance,continue;end;total=total+1;concordant=concordant+double(sign(scoreDelta)==sign(errorDelta));end,end
end
end
function value=localRatio(n,d),value=n/max(d,1);end
function value=localStat(data,kind),data=data(isfinite(data));if isempty(data),value=NaN;else,value=feval(kind,data);end,end
function value=localPercentile(data,p),data=sort(data(isfinite(data)));if isempty(data),value=NaN;return;end;position=1+(numel(data)-1)*p;lo=floor(position);hi=ceil(position);value=data(lo)+(position-lo)*(data(hi)-data(lo));end
