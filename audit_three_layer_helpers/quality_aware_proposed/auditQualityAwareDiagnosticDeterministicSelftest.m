function results = auditQualityAwareDiagnosticDeterministicSelftest(root)
%AUDITQUALITYAWAREDIAGNOSTICDETERMINISTICSELFTEST No random physical packet.
cfg=auditQualityAwareDiagnostic20Config(root);H=[1+.2i .3-.1i;-.2+.4i .8-.3i];X=[1 0 1 0 1;0 1 1 1 0];Y=H*X;reliability=10*ones(1,5);valid=true(1,5);
r1=auditBuildFixedRadiusLegacyObservation(X,Y,3,valid,reliability,1,cfg);r3=auditBuildFixedRadiusLegacyObservation(X,Y,3,valid,reliability,3,cfg);
r1Fail=auditBuildFixedRadiusLegacyObservation(X,Y,3,[false false true false true],reliability,1,cfg);r3Fail=auditBuildFixedRadiusLegacyObservation(X,Y,3,[false false true false false],reliability,3,cfg);
results.fixedRadius1Exact=r1.accepted&&r1.selectedRadius==1&&~r1Fail.accepted;
results.fixedRadius3Exact=r3.accepted&&r3.selectedRadius==3&&~r3Fail.accepted;
direct=auditBuildLocalMimoPseudoObservation(X,Y,3,valid,reliability,cfg.radii,cfg.llrThreshold,2);common=auditBuildFixedRadiusLegacyObservation(X,Y,3,valid,reliability,2,cfg);
results.fixedRadius2FormulaEquivalence=isequaln(direct,common);

audit=localAuditRecords(H,[.1 .05 .2],[true true true],[true true true],1);offline=auditEvaluateQualityWindowAgainstTruthOffline(audit,repmat(reshape(H,1,1,2,2),64,1,1,1),7,1,1,cfg.trueErrorTieTolerance);
expectedAbsolute=norm(.1*eye(2),'fro')^2;expectedNormalized=expectedAbsolute/norm(H,'fro')^2;
results.trueErrorFormula=abs(offline.candidateTable.trueAbsoluteError(1)-expectedAbsolute)<1e-12&&abs(offline.candidateTable.trueNormalizedError(1)-expectedNormalized)<1e-12;
target=offline.targetTable;results.oracleBestRadius=target.oracleBestRadiusAfterInnovation==2;
oracleError=norm(.05*eye(2),'fro')^2/norm(H,'fro')^2;expectedRegret=expectedNormalized-oracleError;results.regretFormula=abs(target.selectionRegretAbs-expectedRegret)<1e-12&&abs(target.selectionRegretRelative-expectedRegret/oracleError)<1e-12;

singleAudit=localAuditRecords(H,[.1 0 .2],[false true false],[false true false],2);single=auditEvaluateQualityWindowAgainstTruthOffline(singleAudit,repmat(reshape(H,1,1,2,2),64,1,1,1),7,1,1,cfg.trueErrorTieTolerance);
results.singleCandidate=single.targetTable.selectionIsOracleBest&&single.targetTable.selectionRegretAbs==0;
noneAudit=localAuditRecords(H,[.1 0 .2],[false false false],[false false false],NaN);none=auditEvaluateQualityWindowAgainstTruthOffline(noneAudit,repmat(reshape(H,1,1,2,2),64,1,1,1),7,1,1,cfg.trueErrorTieTolerance);
results.noCandidate=isnan(none.targetTable.oracleBestRadiusAfterInnovation)&&isnan(none.targetTable.selectionRegretAbs);

online=struct('hFinal',(1:8)','PFinal',eye(8),'selectedRadius',1,'Rda',eye(8),'nis',2,'counts',[1 2 3]);onlineBefore=online;
enabled=auditEvaluateQualityWindowAgainstTruthOffline(audit,repmat(reshape(H,1,1,2,2),64,1,1,1),7,1,1,cfg.trueErrorTieTolerance);
results.onlineOfflineIsolation=isequaln(online,onlineBefore)&&height(enabled.candidateTable)==3;
perturbed=auditEvaluateQualityWindowAgainstTruthOffline(audit,repmat(reshape(2*H,1,1,2,2),64,1,1,1),7,1,1,cfg.trueErrorTieTolerance);
results.truthPerturbationIsolation=isequaln(online,onlineBefore)&&any(enabled.candidateTable.trueNormalizedError~=perturbed.candidateTable.trueNormalizedError);

calibration=auditSummarizeQualityWindowCalibration(offline.candidateTable,offline.targetTable,cfg.trueErrorTieTolerance);overall=calibration(calibration.aggregationLevel=="overall",:);
results.pairwiseOrderingAgreement=overall.validPairCount==3&&overall.pairwiseOrderingAgreement>=0&&overall.pairwiseOrderingAgreement<=1;
results.calibrationAggregation=overall.validSelectionCount==1&&isfinite(overall.zeroRegretRate)&&isfinite(overall.p95RegretAbs);
results.paddingTruthIsolation=all(offline.candidateTable.targetIndex==1)&&all(offline.candidateTable.targetSubcarrier==7);

officialExisted=exist(cfg.diagnosticOutput,'dir')==7;temporary=[tempname '_qa_diag20_dry'];cleanup=onCleanup(@()localCleanup(temporary));dry=auditQualityAwareProposedDiagnostic20(root,'dryRun',true,'outputDirectory',temporary);
schema=auditQualityAwareDiagnostic20Schema();schemaNames=fieldnames(schema);schemaPass=all(cellfun(@(name)isequal(dry.tables.(name).Properties.VariableNames,schema.(name)),schemaNames));
results.diagnostic20DryRun=dry.dryRun&&dry.randomPhysicalPacketCount==0&&numel(dry.methods)==11&&schemaPass&&((exist(cfg.diagnosticOutput,'dir')==7)==officialExisted);
results.onlineInterfacesExcludeTruth=localTruthInterfacePass();
results.oldRegression=dry.preflight.deterministicReportsPass&&dry.preflight.mjcdOjcdRelativeDifference<=1e-8&&dry.preflight.protectedHashesPass;
values=cellfun(@(name)results.(name),fieldnames(results));assert(all(values),'Quality-aware diagnostic deterministic self-test failed.');
fprintf('Quality-aware diagnostic deterministic self-test PASS: %d/%d; random packets=0.\n',nnz(values),numel(values));
end

function audit=localAuditRecords(H,offsets,feasible,accepted,selectedRadius)
count=3;records=struct('symbolIndex',ones(count,1),'targetIndex',ones(count,1),'targetSubcarrier',7*ones(count,1),'candidateRadius',(1:3)','onlineQualityScore',[3;1;2],'posteriorTraceRatio',[3;1;2],'normalizedResidual',[.3;.1;.2],'gramRcond',[.5;.5;.5],'effectiveSampleCount',3*ones(count,1),'meanDecisionCorrectProbability',.9*ones(count,1),'decisionInflationFactor',1.1*ones(count,1),'normalizedNis',[2;1;1.5],'nisInflationFactor',ones(count,1),'traceRls',ones(count,1),'traceRda',2*ones(count,1),'feasibleBeforeInnovation',logical(feasible(:)),'acceptedAfterInnovation',logical(accepted(:)),'selectedByOnlineMethod',false(count,1),'hDaFeature',nan(8,count));
for i=1:count,records.hDaFeature(:,i)=auditChannelMatrixToFeatureVector(H+offsets(i)*eye(2));end;if isfinite(selectedRadius),records.selectedByOnlineMethod(selectedRadius)=true;end
audit=struct('candidateRecordCursor',count,'candidateRecords',records);
end
function pass=localTruthInterfacePass()
folder=fileparts(mfilename('fullpath'));names={'auditSelectQualityAwareWindow.m','auditQualityAwareDaKalmanUpdate.m','auditQualityAwareProposedCausalEstimates.m'};pass=true;
for i=1:numel(names),text=fileread(fullfile(folder,names{i}));firstLine=extractBefore(text,newline);pass=pass&&~contains(lower(firstLine),'true');end
end
function localCleanup(path),if exist(path,'dir'),rmdir(path,'s');end,end
