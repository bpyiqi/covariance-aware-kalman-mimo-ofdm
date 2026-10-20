function result = auditEvaluateQualityWindowAgainstTruthOffline(audit,Htrue,dataSubcarriers,payloadSymbols,packetIndex,tieTolerance)
%AUDITEVALUATEQUALITYWINDOWAGAINSTTRUTHOFFLINE Post-packet truth audit only.
% Htrue is intentionally absent from every online estimator/select/update API.
count=audit.candidateRecordCursor;records=audit.candidateRecords;indices=(1:count).';
symbolIndex=records.symbolIndex(indices);targetIndex=records.targetIndex(indices);targetSubcarrier=records.targetSubcarrier(indices);candidateRadius=records.candidateRadius(indices);
assert(all(targetSubcarrier==reshape(dataSubcarriers(targetIndex),[],1)),'Offline target/subcarrier mapping mismatch.');
trueAbsoluteError=nan(count,1);trueNormalizedError=nan(count,1);
for row=1:count
    if ~records.feasibleBeforeInnovation(row),continue;end
    Hda=auditFeatureVectorToChannelMatrix(records.hDaFeature(:,row));truth=squeeze(Htrue(targetSubcarrier(row),symbolIndex(row),:,:));
    trueAbsoluteError(row)=norm(Hda-truth,'fro')^2;trueNormalizedError(row)=trueAbsoluteError(row)/max(norm(truth,'fro')^2,eps);
end
candidateTable=table(repmat(payloadSymbols,count,1),repmat(packetIndex,count,1),symbolIndex,targetIndex,targetSubcarrier,candidateRadius, ...
    records.onlineQualityScore(indices),records.posteriorTraceRatio(indices),records.normalizedResidual(indices),records.gramRcond(indices),records.effectiveSampleCount(indices),records.meanDecisionCorrectProbability(indices),records.decisionInflationFactor(indices),records.normalizedNis(indices),records.nisInflationFactor(indices),records.traceRls(indices),records.traceRda(indices),trueAbsoluteError,trueNormalizedError,records.feasibleBeforeInnovation(indices),records.acceptedAfterInnovation(indices),records.selectedByOnlineMethod(indices), ...
    'VariableNames',{'payloadSymbols','packetIndex','symbolIndex','targetIndex','targetSubcarrier','candidateRadius','onlineQualityScore','posteriorTraceRatio','normalizedResidual','gramRcond','effectiveSampleCount','meanDecisionCorrectProbability','decisionInflationFactor','normalizedNis','nisInflationFactor','traceRls','traceRda','trueAbsoluteError','trueNormalizedError','feasibleBeforeInnovation','acceptedAfterInnovation','selectedByOnlineMethod'});
keys=unique(candidateTable(:,{'symbolIndex','targetIndex','targetSubcarrier'}),'rows');targetRows=cell(height(keys),1);
for keyIndex=1:height(keys)
    group=candidateTable(candidateTable.symbolIndex==keys.symbolIndex(keyIndex)&candidateTable.targetIndex==keys.targetIndex(keyIndex),:);
    before=group.feasibleBeforeInnovation&isfinite(group.trueNormalizedError);after=group.acceptedAfterInnovation&isfinite(group.trueNormalizedError);selected=find(group.selectedByOnlineMethod,1);
    [oracleBefore,errorBefore]=localBest(group,before,tieTolerance);[oracleAfter,errorAfter]=localBest(group,after,tieTolerance);
    if isempty(selected)||isnan(oracleAfter),selectedRadius=NaN;selectedError=NaN;regretAbsolute=NaN;regretRelative=NaN;selectionIsOracleBest=false;else,selectedRadius=group.candidateRadius(selected);selectedError=group.trueNormalizedError(selected);regretAbsolute=max(0,selectedError-errorAfter);regretRelative=regretAbsolute/max(errorAfter,eps);selectionIsOracleBest=selectedRadius==oracleAfter;end
    targetRows{keyIndex}=table(payloadSymbols,packetIndex,keys.symbolIndex(keyIndex),keys.targetIndex(keyIndex),keys.targetSubcarrier(keyIndex),selectedRadius,oracleBefore,oracleAfter,selectedError,errorBefore,errorAfter,regretAbsolute,regretRelative,selectionIsOracleBest,nnz(before),nnz(after), ...
        'VariableNames',{'payloadSymbols','packetIndex','symbolIndex','targetIndex','targetSubcarrier','selectedRadius','oracleBestRadiusBeforeInnovation','oracleBestRadiusAfterInnovation','selectedTrueError','oracleBestTrueErrorBeforeInnovation','oracleBestTrueErrorAfterInnovation','selectionRegretAbs','selectionRegretRelative','selectionIsOracleBest','feasibleCandidateCountBeforeInnovation','acceptedCandidateCountAfterInnovation'});
end
targetTable=vertcat(targetRows{:});result=struct('candidateTable',candidateTable,'targetTable',targetTable);
end

function [radius,errorValue]=localBest(group,mask,tolerance)
radius=NaN;errorValue=NaN;if ~any(mask),return;end
errorValue=min(group.trueNormalizedError(mask));eligible=mask&abs(group.trueNormalizedError-errorValue)<=tolerance;radius=min(group.candidateRadius(eligible));
end
