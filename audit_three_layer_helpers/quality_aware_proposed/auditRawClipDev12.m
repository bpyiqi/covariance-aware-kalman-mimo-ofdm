function result=auditRawClipDev12(root,options)
%AUDITRAWCLIPDEV12 Dry-run or offline-only clipping development analysis.
arguments,root (1,:) char,options.run (1,1) logical=false,end
cfg=auditRawClipConfig(root);preflight=auditRawClipPreflight(cfg);expectedRows=12*7*5;
if ~options.run
    assert(exist(cfg.outputDirectory,'dir')~=7,'Dry-run must not create the formal output directory.');
    result=struct('dryRun',true,'sourceComplete',preflight.sourceComplete,'verifiedChunkCount',preflight.chunkCount, ...
        'expectedFrozenReceiverRows',expectedRows,'receiverRuns',0,'newPhysicalSeedsConsumed',0,'outputDirectory',string(cfg.outputDirectory));
    fprintf('raw-clipping dev12 dry-run PASS: COMPLETE=1 chunks=12 hashes=12 receiverRuns=0 physicalSeeds=0 outputCreated=0.\n');return;
end
auditRefuseNonemptyOutput(cfg.outputDirectory);
if exist(cfg.outputDirectory,'dir')~=7,mkdir(cfg.outputDirectory);end
source=load(preflight.checkpointPath,'cfg');cfg.decoder=source.cfg.ldpc;
calibration=auditRawClipEvaluate(cfg,preflight.chunkPaths,cfg.calibrationScenarios,cfg.clipGrid,"hard");
ideal=auditLdpcIdealLlrSelftest(root);noiseless=auditNoiselessPerfectCsiLdpcChainSelftest(root);
cfg.invariantTestsPass=ideal.positiveLlrMeansZero&&noiseless.codewordPassRate==1;
[gridTable,methodGrid,snrGrid,selection]=auditRawClipCalibrationSummary(calibration,cfg);
diagnostic=localMethodDiagnostic(methodGrid,cfg);bootstrap=auditRawClipBootstrap(calibration,cfg);
Cstar=selection.selectedC;if isnan(Cstar),Cstar=Inf;end
holdoutDetail=auditRawClipEvaluate(cfg,preflight.chunkPaths,cfg.holdoutScenarios,unique([Cstar Inf],'stable'),"hard");
[holdout,transitions,holdoutGates]=auditRawClipHoldoutSummary(holdoutDetail,cfg,Cstar);
if cfg.enableTanhDiagnostic
    tanhDetail=auditRawClipEvaluate(cfg,preflight.chunkPaths,1:12,cfg.clipGrid,"tanh");
    [tanhGrid,tanhMethod]=auditRawClipCalibrationSummary(tanhDetail(ismember(tanhDetail.scenarioIndex,cfg.calibrationScenarios),:),cfg);
    tanhDiagnostic=localCommonSummaryRows(tanhGrid,tanhMethod);
else
    tanhDetail=table();tanhDiagnostic=table();
end
infFrequency=mean(bootstrap.selectedInf);boundaryFrequency=mean(bootstrap.boundaryHit);reference=gridTable(gridTable.clipLevel==Inf,:);selected=gridTable(gridTable.clipLevel==Cstar,:);
calibrationImproved=selected.pooledNll<reference.pooledNll;calibrationMethodGate=selected.maximumMethodNllDegradation<=cfg.methodNllTolerance;
candidateEligible=selection.hasNonInfFeasible&&~selection.selectedInf&&~selection.boundaryHit&&calibrationImproved&&calibrationMethodGate&& ...
    holdoutGates.pooledNllNotWorse&&holdoutGates.methodNllGate&&holdoutGates.hardBitsUnchanged&&holdoutGates.preBerUnchanged&& ...
    holdoutGates.passToFailNotIncreased&&holdoutGates.reverseCrossingNotIncreased&&ideal.positiveLlrMeansZero&& ...
    noiseless.codewordPassRate==1&&infFrequency<.25&&boundaryFrequency<.25&&~holdoutGates.hasNonfinite;
selectedCandidate=table(Cstar,candidateEligible,selection.feasibleCandidateCount,selection.hasNonInfFeasible, ...
    selection.selectedInf,selection.boundaryHit,infFrequency,boundaryFrequency,false,false, ...
    'VariableNames',{'selectedC','candidateEligible','feasibleCandidateCount','hasNonInfFeasible','selectedInf', ...
    'boundaryHit','bootstrapInfFrequency','bootstrapBoundaryFrequency','humanApproved','DECODER_CLIP_APPROVED'});
calibrationGrid=[gridTable;methodGrid;snrGrid];localWriteArtifacts(cfg,preflight,calibrationGrid,selectedCandidate,diagnostic,bootstrap, ...
    holdout,transitions,tanhDiagnostic,calibration,holdoutDetail,tanhDetail,selection,holdoutGates,ideal,noiseless);
result=struct('dryRun',false,'selectedC',Cstar,'candidateEligible',candidateEligible,'receiverRuns',0, ...
    'newPhysicalSeedsConsumed',0,'outputDirectory',string(cfg.outputDirectory));
end
function diagnostic=localMethodDiagnostic(methodGrid,cfg)
rows=cell(numel(cfg.methods),1);for i=1:numel(cfg.methods),x=methodGrid(methodGrid.scopeValue==cfg.methods(i),:);[~,q]=min(x.pooledNll);rows{i}=table(cfg.methods(i),x.clipLevel(q),x.pooledNll(q),x.pooledNll(x.clipLevel==Inf), ...
    'VariableNames',{'method','diagnosticC','minimumCalibrationNll','rawCalibrationNll'});end;diagnostic=vertcat(rows{:});
end
function output=localCommonSummaryRows(first,second)
% Optional diagnostics need only columns that are meaningful for both scopes.
names=intersect(string(first.Properties.VariableNames),string(second.Properties.VariableNames),'stable');
assert(~isempty(names),'No common summary columns are available for concatenation.');
output=[first(:,cellstr(names));second(:,cellstr(names))];
end
function localWriteArtifacts(cfg,preflight,grid,candidate,diagnostic,bootstrap,holdout,transitions,tanhDiagnostic,calibration,holdoutDetail,tanhDetail,selection,holdoutGates,ideal,noiseless)
out=cfg.outputDirectory;writetable(grid,fullfile(out,'raw_clip_calibration_grid.csv'));writetable(candidate,fullfile(out,'raw_clip_selected_candidate.csv'));
writetable(diagnostic,fullfile(out,'raw_clip_method_specific_diagnostic.csv'));writetable(bootstrap,fullfile(out,'raw_clip_bootstrap.csv'));
writetable(holdout,fullfile(out,'raw_clip_holdout_results.csv'));writetable(transitions,fullfile(out,'raw_clip_transition_audit.csv'));
writetable(tanhDiagnostic,fullfile(out,'raw_clip_optional_tanh_diagnostic.csv'));
save(fullfile(out,'raw_clip_results.mat'),'cfg','preflight','grid','candidate','diagnostic','bootstrap','holdout','transitions', ...
    'tanhDiagnostic','calibration','holdoutDetail','tanhDetail','selection','holdoutGates','ideal','noiseless','-v7.3');
file=fopen(fullfile(out,'raw_clip_manifest.txt'),'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));
fprintf(file,'experimentName=%s\nsourceDirectory=%s\ntransform=Lout=sign(Lraw).*min(abs(Lraw),C)\nclipGrid=%s\ncalibrationScenarios=1:8\nholdoutScenarios=9:12\nbootstrapSeed=%d\nbootstrapCount=%d\nreceiverRuns=0\nnewPhysicalSeedsConsumed=0\n',cfg.experimentName,cfg.sourceDirectory,mat2str(cfg.clipGrid),cfg.bootstrapSeed,cfg.bootstrapCount);
for i=1:preflight.chunkCount,fprintf(file,'sourceChunk=%s SHA256=%s\n',preflight.chunkPaths(i),preflight.chunkHashes(i));end
clear cleanup;localReport(cfg,candidate,grid,holdout,bootstrap);localCandidate(out,candidate);fclose(fopen(fullfile(out,'COMPLETE'),'w'));
end
function localReport(cfg,candidate,grid,holdout,bootstrap)
file=fopen(fullfile(cfg.outputDirectory,'raw_clip_report.txt'),'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));pooled=grid(grid.scope=="pooled",:);raw=pooled(pooled.clipLevel==Inf,:);selected=pooled(pooled.clipLevel==candidate.selectedC,:);
fprintf(file,'Raw-LLR symmetric clipping development analysis. No beta is applied and no receiver is rerun.\n');
fprintf(file,'CStar=%.9g candidateEligible=%d humanApproved=false. Calibration pooled NLL raw/selected %.9g/%.9g.\n',candidate.selectedC,candidate.candidateEligible,raw.pooledNll,selected.pooledNll);
fprintf(file,'Bootstrap C=Inf frequency %.6g; C=5 frequency %.6g. Holdout selection influence=false.\n',mean(bootstrap.selectedInf),mean(bootstrap.boundaryHit));
fprintf(file,'Holdout pooled raw/clipped NLL %.9g/%.9g. COMPLETE means offline analysis complete, not decoder approval. DECODER_CLIP_APPROVED is not generated.\n',holdout.pooledNll(holdout.scope=="pooled"&holdout.mode=="raw"),holdout.pooledNll(holdout.scope=="pooled"&holdout.mode=="clipped"));
end
function localCandidate(out,candidate)
file=fopen(fullfile(out,'DECODER_CLIP_CANDIDATE'),'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));
fprintf(file,'selectedC=%.17g\ncandidateEligible=%d\nhumanApproved=false\nDECODER_CLIP_APPROVED=false\n',candidate.selectedC,candidate.candidateEligible);
end
