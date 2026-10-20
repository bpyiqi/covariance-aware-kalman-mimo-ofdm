function result=auditUncertaintyBypassCapture(root,mode)
% Mini execution is initiated only by the user's explicit MATLAB entry call.
if strcmp(mode,'mini')
    result=localMini(root); return;
end
result=struct('mode',string(mode),'receiverRuns',0,'physicalSeeds',0, ...
    'captureDefault',false,'formalPaths',{{'auditMechanismRunSingleEstimator -> auditMechanismOnlineReceive', ...
    'auditCovarianceAwareOjcdReceive -> auditOjcdTwoLayerSymbol'}});
fprintf('uncertainty bypass capture v1 dry-run\nreceiverRuns=0\nphysicalSeeds=0\ncaptureDefault=false\n');
end

function result=localMini(root)
out=fullfile(root,'results_three_layer_validation','uncertainty_propagation_bypass_capture_mini_v1');
receiverRunsPlanned=6;uniquePhysicalInputsPlanned=1;methodsPlanned=3;capturePairsPlanned=3;newUncertaintyAlgorithmEnabled=0;
fprintf('receiverRunsPlanned=%d\nuniquePhysicalInputsPlanned=%d\nmethodsPlanned=%d\ncapturePairsPlanned=%d\nnewUncertaintyAlgorithmEnabled=%d\n',receiverRunsPlanned,uniquePhysicalInputsPlanned,methodsPlanned,capturePairsPlanned,newUncertaintyAlgorithmEnabled);
assert(receiverRunsPlanned==6&&uniquePhysicalInputsPlanned==1&&methodsPlanned==3&&capturePairsPlanned==3&&newUncertaintyAlgorithmEnabled==0,'Frozen mini-run scope assertion failed.');
fprintf('executionLedgerInitialized=1\n');
assert(exist(out,'dir')~=7,'Refusing to overwrite existing output directory.');
cfg=auditQualityAwareDefaultConfig(root); methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"];
rng(20260724,'twister'); packet=auditQualityAwareMiniPacket(cfg,1); sharedState=rng; rows=cell(numel(methods),1); semantic=cell(numel(methods),1); ledger=localEmptyLedger();
try
    for i=1:numel(methods)
        rng(sharedState); [ledger,off]=localLedgerRun(ledger,cfg,packet,methods(i),false,'off');
        rng(sharedState); [ledger,on]=localLedgerRun(ledger,cfg,packet,methods(i),true,'on');
        rows{i}=localCompare(methods(i),off,on); semantic{i}=localSemantic(methods(i),on);
    end
catch ME
    fprintf(2,'MINI_RUN_PRIMARY_ERROR\n');
    fprintf(2,'%s\n',getReport(ME,'extended','hyperlinks','off'));
    fprintf(2,'primaryErrorIdentifier=%s\nprimaryErrorMessage=%s\n',ME.identifier,ME.message);
    try
        localPrintLedger(ledger(ledger.attempted,:));
    catch ledgerPrintError
        fprintf(2,'LEDGER_PRINT_ERROR: %s\n',ledgerPrintError.message);
    end
    rethrow(ME);
end
ledger=ledger(ledger.attempted,:);
equivalence=vertcat(rows{:}); semanticAudit=vertcat(semantic{:}); assert(all(equivalence.passed)&&all(semanticAudit.passed),'Dynamic bypass gates failed.');
executionLedger=ledger;
mkdir(out); writetable(equivalence,fullfile(out,'bypass_capture_equivalence.csv')); writetable(semanticAudit,fullfile(out,'bypass_capture_semantic_audit.csv'));
writetable(executionLedger,fullfile(out,'bypass_capture_execution_ledger.csv'));
save(fullfile(out,'bypass_capture_results.mat'),'cfg','packet','equivalence','semanticAudit','ledger','-v7.3');
summary=localSummarizeExecutionLedger(ledger); fid=fopen(fullfile(out,'bypass_capture_report.txt'),'w'); fprintf(fid,'actualReceiverRuns=%d\nattemptedActualReceiverRuns=%d\ncompletedActualReceiverRuns=%d\nuniquePhysicalInputsActuallyUsed=%d\ncaptureOffRunsCompleted=%d\ncaptureOnRunsCompleted=%d\noutputDirectoryCreated=1\nCOMPLETEWritten=1\nnewPhysicalSeedsActuallyGenerated=%g\n',summary.actualReceiverRuns,summary.attemptedActualReceiverRuns,summary.completedActualReceiverRuns,summary.uniquePhysicalInputsActuallyUsed,summary.captureOffRunsCompleted,summary.captureOnRunsCompleted,summary.newPhysicalSeedsActuallyGenerated); fclose(fid);
localManifest(root,out); fclose(fopen(fullfile(out,'COMPLETE'),'w')); result=struct('receiverRuns',6,'uniquePhysicalInputs',1,'capturePairs',3,'outputDirectory',out);
end

function [ledger,run]=localLedgerRun(ledger,cfg,packet,method,capture,mode)
index=find(~ledger.attempted,1);
assert(~isempty(index),'Execution ledger capacity exhausted.');
ledger.method(index)=string(method); ledger.captureMode(index)=string(mode); ledger.attempted(index)=true;
ledger.receiverFunction(index)="auditMechanismRunSingleEstimator -> auditMechanismOnlineReceive";
ledger.physicalInputId(index)="shared_input_1"; ledger.physicalSeedId(index)="physical_seed_20260724";
ledger.newPhysicalSeedGenerated(index)=(index==1);
ledger.startedTimestamp(index)=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
ledger.resultSource(index)="actualReceiverRun"; ledger.isSynthetic(index)=false; ledger.isActualReceiverRun(index)=true;
run=localRun(cfg,packet,method,capture); ledger.completed(index)=true; ledger.completedTimestamp(index)=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
end

function ledger=localEmptyLedger()
ledger=table(strings(6,1),strings(6,1),false(6,1),false(6,1),strings(6,1),strings(6,1),strings(6,1),false(6,1),strings(6,1),strings(6,1),strings(6,1),false(6,1),false(6,1), ...
    'VariableNames',{'method','captureMode','attempted','completed','receiverFunction','physicalInputId','physicalSeedId','newPhysicalSeedGenerated','startedTimestamp','completedTimestamp','resultSource','isSynthetic','isActualReceiverRun'});
end

function localPrintLedger(ledger)
summary=localSummarizeExecutionLedger(ledger);
fprintf('actualReceiverRuns=%d\nattemptedActualReceiverRuns=%d\ncompletedActualReceiverRuns=%d\nuniquePhysicalInputsActuallyUsed=%d\ncaptureOffRunsCompleted=%d\ncaptureOnRunsCompleted=%d\noutputDirectoryCreated=%s\nCOMPLETEWritten=%s\nnewPhysicalSeedsActuallyGenerated=%g\n',summary.actualReceiverRuns,summary.attemptedActualReceiverRuns,summary.completedActualReceiverRuns,summary.uniquePhysicalInputsActuallyUsed,summary.captureOffRunsCompleted,summary.captureOnRunsCompleted,localText(summary.outputDirectoryCreated),localText(summary.COMPLETEWritten),summary.newPhysicalSeedsActuallyGenerated);
if istable(ledger)&&height(ledger)>0,disp(ledger);end
end

function value=localText(v),if isempty(v),value="unknown";elseif v,value="true";else,value="false";end,end

function run=localRun(cfg,packet,method,capture)
online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'validDataMask',packet.validReMask,'validReMask',packet.validReMask,'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',packet.Npayload,'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
before=rng; estimate=auditMechanismRunSingleEstimator(cfg,online,method,struct('bypassCapture',capture)); receiver=auditMechanismOnlineReceive(cfg,online,estimate.Hhat,estimate.onlineEstimationRuntimeSeconds,bypassCapture=capture); after=rng;
useful=receiver.llr(packet.usefulBitMask); bits=receiver.llr<0; valid=repmat(reshape(packet.validReMask,1,numel(cfg.data),packet.Npayload),cfg.bitsPerQam*cfg.NT,1,1); run=struct('Hhat',estimate.Hhat,'receiver',receiver,'capture',capture,'estCapture',localField(estimate,'bypassCapture',struct()),'audit',estimate.audit,'before',before,'after',after,'rawUsefulLlr',useful,'preBer',mean(bits(valid(:))~=packet.codedBits),'bitErrorCount',nnz(bits(valid(:))~=packet.codedBits),'bitCount',nnz(valid),'validDataMask',packet.validReMask);
end

function T=localCompare(method,a,b)
channelEstimatePassed=isequaln(a.Hhat,b.Hhat);
rawUsefulLlrPassed=isequaln(a.rawUsefulLlr,b.rawUsefulLlr);
ldpcInputPassed=isequaln(a.receiver.llr,b.receiver.llr);
preLdpcBerPassed=a.preBer==b.preBer;
bitErrorCountPassed=a.bitErrorCount==b.bitErrorCount;
bitCountPassed=a.bitCount==b.bitCount;
randomStatePassed=isequaln(a.after,b.after);
reliabilityMaskPassed=isfield(b.estCapture,'reliabilityMask');
candidateMaskPassed=isfield(b.estCapture,'candidateMask');
selectedCandidateMaskPassed=isfield(b.estCapture,'selectedCandidateMask');
receiverUpdatesPassed=a.audit.daUpdateCount==b.audit.daUpdateCount;
daAcceptRejectPassed=localField(a.audit,'candidateFeasibleCount',0)==localField(b.audit,'candidateFeasibleCount',0)&&localField(a.audit,'noCandidateCount',0)==localField(b.audit,'noCandidateCount',0);
daFallbackPassed=localField(a.audit,'fallbackCount',0)==localField(b.audit,'fallbackCount',0);
perTargetUpdatesPassed=localField(a.audit,'daUpdateCount',0)==localField(b.audit,'daUpdateCount',0);
if startsWith(string(method),"Base")
    reliabilityMaskPassed=true; candidateMaskPassed=true; selectedCandidateMaskPassed=true;
    reliabilityGate="reliabilityMask(notApplicable)"; candidateGate="candidateMask(notApplicable)"; selectedGate="selectedCandidateMask(notApplicable)";
else
    reliabilityGate="reliabilityMask"; candidateGate="candidateMask"; selectedGate="selectedCandidateMask";
end
names=["channelEstimate";"rawUsefulLlr";"ldpcInput";"preLdpcBer";"bitErrorCount";"bitCount";"randomState";reliabilityGate;candidateGate;selectedGate;"daAcceptReject";"daFallback";"perTargetDaUpdates";"receiverUpdates"];
checks=[channelEstimatePassed;rawUsefulLlrPassed;ldpcInputPassed;preLdpcBerPassed;bitErrorCountPassed;bitCountPassed;randomStatePassed;reliabilityMaskPassed;candidateMaskPassed;selectedCandidateMaskPassed;daAcceptRejectPassed;daFallbackPassed;perTargetUpdatesPassed;receiverUpdatesPassed];
methodColumn=repmat(string(method),numel(names),1);
gateColumn=string(names(:));
passedColumn=logical(checks(:));
assert(isscalar(string(method)),'Method must be scalar.');
assert(numel(gateColumn)==numel(passedColumn),'GateCheckCountMismatch');
assert(size(methodColumn,1)==size(gateColumn,1),'GateCheckCountMismatch');
assert(size(gateColumn,1)==size(passedColumn,1),'GateCheckCountMismatch');
T=localMakeGateTable(method,gateColumn,passedColumn);
end

function T=localSemantic(method,run)
T=localEvaluateBypassSemantic(method,run);
end

function v=localField(s,name,default),if isfield(s,name),v=s.(name);else,v=default;end,end
function localManifest(root,out)
files={'Compare_LongPayload_VideoLink_Kalman.m';'Exp_ProblemExistence_CSI_Aging.m';'Audit_ProblemExistence_CSI_Aging.m'}; fid=fopen(fullfile(out,'bypass_capture_manifest.txt'),'w');for i=1:numel(files),[~,h]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',fullfile(root,files{i})));fprintf(fid,'%s %s',files{i},strtrim(h));fprintf(fid,'\n');end;fclose(fid);
end
