function results = auditQualityAwareProposedSelftest(root,varargin)
%AUDITQUALITYAWAREPROPOSEDSELFTEST Deterministic mathematical/causal gates.
parser=inputParser;parser.addParameter('outputDirectory','',@(x)ischar(x)||(isstring(x)&&isscalar(x)));parser.addParameter('runLegacySelftests',true,@(x)islogical(x)&&isscalar(x));parser.parse(varargin{:});options=parser.Results;
cfg=auditQualityAwareDefaultConfig(root);if strlength(string(options.outputDirectory))>0,cfg.auditOutput=char(options.outputDirectory);end;if ~exist(cfg.auditOutput,'dir'),mkdir(cfg.auditOutput);end
H=[1+.2i .3-.1i;-.2+.4i .8-.3i];state=auditChannelMatrixToFeatureVector(H);Hround=auditFeatureVectorToChannelMatrix(state);
results.stateMappingRoundTrip=max(abs(H(:)-Hround(:)))<=eps;

C=[2 .2+.3i 0 0;.2-.3i 1 0 0;0 0 1.5 -.1i;0 0 .1i .8];C=(C+C')/2;
[R,mapAudit]=auditMapComplexCovarianceToRealState(C,cfg);expected=.5*[real(C),-imag(C);imag(C),real(C)];
results.complexCovarianceMapping=norm(R-expected,'fro')<=1e-12;

Xgood=[1 0 1 0;0 1 0 1];nullRow=[1 1 -1 -1];
Ylow=H*Xgood+.01*[nullRow;nullRow];Yhigh=H*Xgood+.1*[nullRow;nullRow];
low=localLs(Xgood,Ylow,1e-6,cfg);high=localLs(Xgood,Yhigh,1e-6,cfg);
results.residualVarianceMonotonicity=trace(high.Rls)>trace(low.Rls);
Xbad=[1 1 1 1;0 .04 .08 .12];Ybad=H*Xbad+.01*[nullRow;nullRow];bad=localLs(Xbad,Ybad,1e-6,cfg);
results.gramConditioningEffect=bad.gramRcond<low.gramRcond&&trace(bad.Rls)>trace(low.Rls);

reliable=auditComputeDecisionReliabilityInflation(10*ones(4,2,3),cfg);
uncertain=auditComputeDecisionReliabilityInflation(2.5*ones(4,2,3),cfg);
results.decisionReliabilityEffect=uncertain.decisionInflationFactor>reliable.decisionInflationFactor;

P=eye(8);Rdecision=.2*eye(8);small=auditComputeInnovationConsistency(zeros(8,1),P,.1*ones(8,1),Rdecision,cfg);
large=auditComputeInnovationConsistency(zeros(8,1),P,3*ones(8,1),Rdecision,cfg);
results.innovationInflationEffect=large.nisInflationFactor>=small.nisInflationFactor&&trace(large.Rda)>=trace(small.Rda);
results.innovationHardRejection=large.rejectedByInnovation&&large.nis>cfg.chiSquareHardThresholdDof8P999;

scoreValues=[.7 .3 .5];candidates=repmat(localCandidateTemplate(),1,3);for i=1:3,candidates(i).radius=i;candidates(i).candidateFeasible=true;candidates(i).qualityScore=scoreValues(i);end
selected=auditSelectQualityAwareWindow(candidates,cfg);results.posteriorTraceSelection=selected.selectedRadius==2;
candidates(1).qualityScore=.3;selectedTie=auditSelectQualityAwareWindow(candidates,cfg);results.tieBreak=selectedTie.selectedRadius==1;

invalid=repmat(localCandidateTemplate(),1,3);selectionInvalid=auditSelectQualityAwareWindow(invalid,cfg);
[hFallback,pFallback,aFallback]=auditQualityAwareDaKalmanUpdate(state,P,selectionInvalid,[],cfg);
results.allCandidatesInvalid=isequal(hFallback,state)&&isequal(pFallback,P)&&aFallback.daUpdateCount==0;

valid=localCandidateTemplate();valid.candidateFeasible=true;valid.radius=1;valid.qualityScore=.5;valid.zDa=state+ones(8,1);valid.Rda=eye(8);
selectionValid=auditSelectQualityAwareWindow(valid,cfg);[hHuge,~,~]=auditQualityAwareDaKalmanUpdate(state,P,selectionValid,1e15*eye(8),cfg);
results.hugeRdaDegeneration=norm(hHuge-state)<=1e-12;
valid.zDa=state;selectionZero=auditSelectQualityAwareWindow(valid,cfg);[hZero,pZero,aZero]=auditQualityAwareDaKalmanUpdate(state,P,selectionZero,[],cfg);
results.zeroInnovation=isequal(hZero,state)&&trace(pZero)<trace(P)&&aZero.daUpdateCount==1;
results.covarianceSymmetry=norm(R-R','fro')<=1e-12&&mapAudit.minEigenvalueAfterFloor>=-1e-12&&norm(pZero-pZero','fro')<=1e-12&&min(eig(pZero))>=-1e-12;

X=[1 0 1;0 1 1];Y=H*X;L=10*ones(4,2,3);validMask=[true true false];
paddingCandidate=auditBuildQualityAwareLocalDaCandidate(X,Y,L,2,validMask,2,state,P,.01,cfg);
results.paddingIsolation=paddingCandidate.effectiveSampleCount==2&&~ismember(3,paddingCandidate.sampleIndices);

candidateA=auditBuildQualityAwareLocalDaCandidate(X,Y,L,2,true(1,3),2,state,P,.01,cfg);
candidateB=auditBuildQualityAwareLocalDaCandidate(X,Y,L,2,true(1,3),2,state,P,.01,cfg);
results.noSameSymbolFeedback=isequaln(candidateA,candidateB);
selectionOne=auditSelectQualityAwareWindow(candidateA,cfg);[~,~,updateOne]=auditQualityAwareDaKalmanUpdate(state,P,selectionOne,[],cfg);
results.oneUpdateUpperBound=updateOne.daUpdateCount<=1;

grid=zeros(3,2,8);gridBefore=grid;grid(2,1,:)=reshape(hZero,1,1,8);delta=grid-gridBefore;delta(2,1,:)=0;
results.crossSubcarrierIsolation=all(delta(:)==0);
chains={state,state,state,state};chains{1}(1)=chains{1}(1)+1;
results.crossMethodIsolation=chains{2}(1)==state(1)&&chains{3}(1)==state(1)&&chains{4}(1)==state(1);

sourceText=fileread(fullfile(fileparts(mfilename('fullpath')),'auditQualityAwareProposedCausalEstimates.m'));
codeOnly=regexprep(sourceText,'%[^\r\n]*','');forbidden={'H_true','trueQam','trueBits','codewordDecodeSuccessAudit'};
results.truthIsolation=all(cellfun(@(token)~contains(codeOnly,token),forbidden));
results.causalPrefixTest=localPrefixTest(cfg);
if options.runLegacySelftests
    auditCausalSmoke('causal_selftest',root);
    auditCausalIntegrationSelftest(root);
    auditCausalPaddingDiagnosticsSelftest(root);
    auditOjcdBaselineSelftest(root);
end
[results.baseCausalRegression,results.causalIntegrationRegression, ...
    results.paddingV2Regression,results.ojcdRegression]=localOldRegression(root);
results.oldMethodRegression=results.baseCausalRegression&&results.causalIntegrationRegression&& ...
    results.paddingV2Regression&&results.ojcdRegression;
results.noExplicitInv=isempty(regexp(regexprep(localDirectoryText(),'%[^\r\n]*',''),'(?<![A-Za-z])inv\s*\(','once'));
results.noEval=isempty(regexp(regexprep(localDirectoryText(),'%[^\r\n]*',''),'(?<![A-Za-z])eval\s*\(','once'));

candidateTable=table(low.normalizedResidual,high.normalizedResidual,low.sigma2Hat,high.sigma2Hat,low.gramRcond,bad.gramRcond,trace(low.Rls),trace(high.Rls),trace(bad.Rls), ...
    'VariableNames',{'lowResidual','highResidual','lowSigma2Hat','highSigma2Hat','goodGramRcond','badGramRcond','lowTraceRls','highTraceRls','badGramTraceRls'});
mappingTable=table(mapAudit.minEigenvalueBeforeFloor,mapAudit.minEigenvalueAfterFloor,mapAudit.eigenFloorApplied,mapAudit.traceRls,mapAudit.conditionRls,norm(R-expected,'fro'), ...
    'VariableNames',{'minEigenvalueBeforeFloor','minEigenvalueAfterFloor','eigenFloorApplied','traceRls','conditionRls','mappingError'});
selectionTable=table(selected.selectedRadius,selected.selectedScore,selectedTie.selectedRadius,selectionInvalid.validCandidateCount, ...
    'VariableNames',{'selectedRadius','selectedScore','tieSelectedRadius','invalidCandidateCount'});
isolationTable=table(results.paddingIsolation,results.noSameSymbolFeedback,results.oneUpdateUpperBound,results.crossSubcarrierIsolation,results.crossMethodIsolation,results.truthIsolation,results.causalPrefixTest, ...
    'VariableNames',{'paddingIsolation','noSameSymbolFeedback','oneUpdateUpperBound','crossSubcarrierIsolation','crossMethodIsolation','truthIsolation','causalPrefixTest'});
protected=localProtected(root);tables=struct('candidate',candidateTable,'mapping',mappingTable,'selection',selectionTable,'isolation',isolationTable);
auditWriteQualityAwareImplementationAudit(cfg,results,tables,protected);
values=cellfun(@(name)results.(name),fieldnames(results));assert(all(values),'Quality-aware deterministic self-test failed.');
fprintf('Quality-aware proposed deterministic self-test PASS: %d/%d.\n',nnz(values),numel(values));
end

function out=localLs(X,Y,noise,cfg),out=auditEstimateLocalLsObservationCovariance(X,Y,(Y*X')/(X*X'),noise,cfg);end
function c=localCandidateTemplate(),c=struct('radius',1,'candidateFeasible',false,'rejectReason',"invalid",'qualityScore',Inf,'zDa',zeros(8,1),'Rda',eye(8));end
function pass=localPrefixTest(cfg)
K=64;N=2;data=[7 8 9];H=repmat(reshape(eye(2),1,1,2,2),K,N,1,1);obs=complex(single(H));X=repmat([1;1i],1,numel(data),N);y=complex(zeros(numel(data),N,2,'single'));
for n=1:N,for d=1:numel(data),y(d,n,:)=single(squeeze(H(data(d),n,:,:))*X(:,d,n));end,end
online=struct('pilotObservation',obs,'receivedData',y,'dataSubcarriers',data,'validDataMask',true(numel(data),N),'noiseVar',.01,'rho',.99);
a=auditQualityAwareProposedCausalEstimates(cfg,online);online.receivedData(:,2,:)=10*online.receivedData(:,2,:);b=auditQualityAwareProposedCausalEstimates(cfg,online);
pass=true;for i=1:numel(a.channelEstimates),pass=pass&&isequaln(a.channelEstimates{i}(:,1,:,:),b.channelEstimates{i}(:,1,:,:));end
end
function [basePass,integrationPass,paddingPass,ojcdPass]=localOldRegression(root)
causalRoot=fullfile(root,'results_three_layer_validation','causal_refactor_smoke');
basePass=localReportFlag(fullfile(causalRoot,'causal_two_stage_self_test_report.txt'),'allCausalSelfTestsPassed=1');
integrationPass=localReportFlag(fullfile(causalRoot,'integration_selftest','causal_integration_selftest_report.txt'),'causalIntegrationImplementationReady=1');
paddingPass=localReportFlag(fullfile(causalRoot,'padding_diagnostics_selftest','causal_padding_diagnostics_selftest_report.txt'),'causalPaddingDiagnosticsReady=1');
ojcdPass=localReportFlag(fullfile(root,'results_three_layer_validation','ojcd_baseline_implementation_audit','ojcd_baseline_selftest_report.txt'),'allTestsPassed=1');
end
function pass=localReportFlag(path,flag),pass=exist(path,'file')==2&&contains(fileread(path),flag);end
function text=localDirectoryText(),files=dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));parts=cell(numel(files),1);for i=1:numel(files),parts{i}=fileread(fullfile(files(i).folder,files(i).name));end;text=strjoin(parts,newline);end
function T=localProtected(root)
paths={fullfile(root,'Compare_LongPayload_VideoLink_Kalman.m');fullfile(root,'Exp_ProblemExistence_CSI_Aging.m');fullfile(root,'Audit_ProblemExistence_CSI_Aging.m')};expected={ '2047d3bc2f551b79975b1b0da545f5d237ae888e466751ded1a688e333f386bc';'e79ffdb32c006d15ccaf9783459ef626b8fd6f3b7fb6635ad0fc3ece271eb4d9';'c47be923f41fc66f902d98b09a8df6958e5c7fe13f26ff4be68e6098a65aece6'};actual=cellfun(@localSha,paths,'UniformOutput',false);unchanged=strcmpi(expected,actual);T=table(string(paths),string(expected),string(actual),unchanged,'VariableNames',{'file','beforeSha256','afterSha256','unchanged'});assert(all(unchanged));
end
function value=localSha(path),f=fopen(path,'rb');assert(f>=0);c=onCleanup(@()fclose(f));bytes=fread(f,inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');md.update(typecast(bytes,'int8'));value=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));end
