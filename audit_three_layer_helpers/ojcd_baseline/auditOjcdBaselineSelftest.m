function results = auditOjcdBaselineSelftest(root)
%AUDITOJCDBASELINESELFTEST Deterministic formula and integration gates only.
cfg=auditOjcdBaselineConfig(root);if ~exist(cfg.auditOutput,'dir'),mkdir(cfg.auditOutput);end
constellation=qammod((0:15).',16,'UnitAveragePower',true);

H=[1+.2i .25-.1i;-.15+.3i .9-.2i];x=constellation([3;14]);y=H*x;
epLow=auditEpDetectorOjcd(y,H,1e-8,constellation);
results.epNoiselessPass=isequal(epLow.hardSymbols,x)&&max(abs(epLow.posteriorMean-x))<1e-5 ...
    &&all(isfinite(epLow.posteriorVariance))&&all(epLow.posteriorVariance>=0)&&~epLow.hasNaN&&~epLow.hasInf;
epHigh=auditEpDetectorOjcd(y,H,20,constellation);
results.epHighNoisePass=mean(epHigh.posteriorVariance)>mean(epLow.posteriorVariance);
epRollback=auditEpDetectorOjcd(y,H,.2,constellation,forceNegativePrecisionIteration=1);
results.rollbackPass=epRollback.negativePrecisionRollbackCount>0&&all(epRollback.lambda>0);

post=auditEpConstellationPosterior([0;100+100i],[.2;1e-6],constellation);
lim=max(abs([real(constellation);imag(constellation)]));
results.posteriorPass=max(abs(post.probabilitySum-1))<1e-12&&all(post.variance>=0) ...
    &&all(abs(real(post.mean))<=lim+eps)&&all(abs(imag(post.mean))<=lim+eps)&&~post.hasNaN&&~post.hasInf;

D=4;R=toeplitz(.72.^(0:D-1));P=2;cov=struct();cov.Rhdhd=cell(2);cov.Rhdhp=cell(2);cov.Rhphp=cell(2);
for a=1:2
    for b=1:2
        scale=double(a==b);cov.Rhdhd{a,b}=scale*R;cov.Rhdhp{a,b}=zeros(D,P);cov.Rhphp{a,b}=scale*eye(P);
    end
end
pil=cell(2);for rx=1:2,for tx=1:2,pil{rx,tx}=complex([.2;.4]);end,end
tr=auditTraditionalLmmseEp(pil,cov,.1);cov.Wtraditional=tr.weights;
results.traditionalPass=isequal(size(cov.Rhdhp{1,1}),[D P])&&isequal(size(cov.Rhphp{1,1}),[P P]) ...
    &&isequal(size(tr.weights{1}),[D P])&&isequal(size(tr.Hdata),[D 2 2])&&~tr.hasNaN&&~tr.hasInf;

% Equation-(18) and Appendix-B equivalence in a paper-assumption case:
% independent Tx/Rx channel blocks, zero pilot estimator W1, nonzero soft symbols.
xhat=[constellation([2 5 8 11]) constellation([4 7 10 13])];V=.03*ones(D,2);
H0=complex(zeros(D,2,2));yt=[.4+.2i -.3+.1i;.7-.1i .2+.4i;-.2+.3i .5-.2i;.1-.5i -.4-.1i];
oj=auditOjcdLmmseEpAdapted(yt,H0,xhat,V,cov,.07,symbolMagnitudeFloor=1e-10);
Csingle=kron(eye(2),R);Chh=kron(eye(2),Csingle);
mj=auditMjcdReferenceTiny(yt,xhat,V,Chh,.07);
results.tinyK=D;results.mjcdOjcdRelativeDifference=norm(oj.Hdata(:)-mj.Hdata(:))/max(norm(mj.Hdata(:)),eps);
results.mjcdOjcdPass=results.mjcdOjcdRelativeDifference<=1e-8;

zeroV=zeros(D,2);oj0=auditOjcdLmmseEpAdapted(yt,H0,xhat,zeroV,cov,.07,symbolMagnitudeFloor=1e-10);
mj0=auditMjcdReferenceTiny(yt,xhat,zeroV,Chh,.07);
zeroDifference=norm(oj0.Hdata(:)-mj0.Hdata(:))/max(norm(mj0.Hdata(:)),eps);
results.zeroErrorPass=zeroDifference<=1e-8;
ojLargeV=auditOjcdLmmseEpAdapted(yt,H0,xhat,10*V,cov,.07,symbolMagnitudeFloor=1e-10);
results.varianceInfluencePass=norm(ojLargeV.weights{1}-oj.weights{1},'fro')>1e-10;

results.ojcdTrueQamOnlineUseCount=oj.ojcdTrueQamOnlineUseCount;
results.ojcdHtrueOnlineUseCount=oj.ojcdHtrueOnlineUseCount;
results.ojcdTrueBitsOnlineUseCount=oj.ojcdTrueBitsOnlineUseCount;
results.ojcdTestCovarianceUseCount=oj.ojcdTestCovarianceUseCount;
results.futureSymbolReadCount=oj.futureSymbolReadCount;
results.noncausalInterpolationUseCount=oj.noncausalInterpolationUseCount;
results.testTruthOnlineUseCount=oj.testTruthOnlineUseCount;
results.truthLeakagePass=all([results.ojcdTrueQamOnlineUseCount results.ojcdHtrueOnlineUseCount ...
    results.ojcdTrueBitsOnlineUseCount results.ojcdTestCovarianceUseCount results.testTruthOnlineUseCount]==0);
results.causalityPass=results.futureSymbolReadCount==0&&results.noncausalInterpolationUseCount==0;

validMask=[true(D-1,1);false];llrGrid=repmat(reshape(epLow.bitLlr,1,2,4),D,1,1);
llr=llrGrid(:);useful=llr(repelem(validMask,8));
results.paddingPass=numel(useful)==8*(D-1)&&~validMask(end);
epA=auditEpDetectorOjcd(y,H,.1,constellation);epB=auditEpDetectorOjcd(y,H,.1,constellation);
results.sameCsiEpPass=isequaln(epA.posteriorMean,epB.posteriorMean)&& ...
    isequaln(epA.posteriorVariance,epB.posteriorVariance)&&isequaln(epA.bitLlr,epB.bitLlr);

% Deterministic Mini-interface tensor test. It exercises symbol slicing,
% causal state propagation, padding-target rejection, and 2x2 dimensions
% without constructing a random packet or invoking LDPC.
Ns=3;obs=complex(zeros(cfg.NFFT,Ns,2,2,'single'));received=complex(zeros(numel(cfg.data),Ns,2,'single'));
testSymbols=repmat([constellation(2);constellation(11)],1,numel(cfg.data));
for n=1:Ns
    for k=1:cfg.NFFT
        obs(k,n,:,:)=single([1+.001*k+.01i*n .12-.03i;-.08+.02i .85-.001*k-.01i*n]);
    end
    for d=1:numel(cfg.data)
        received(d,n,:)=single(squeeze(obs(cfg.data(d),n,:,:))*testSymbols(:,d));
    end
end
validRe=true(numel(cfg.data),Ns);validRe(end,end)=false;
miniPacket=struct('Npayload',Ns,'obs',obs,'y',received,'validReMask',validRe);
[miniBase,miniProposed,miniGate]=auditOjcdMiniCausalEstimates(cfg,miniPacket);
results.miniTensorInterfacePass=isequal(size(miniBase),[cfg.NFFT Ns 2 2])&& ...
    isequal(size(miniProposed),[cfg.NFFT Ns 2 2])&&~any(isnan(miniBase(:)))&& ...
    ~any(isinf(miniProposed(:)))&&miniGate.paddingTargetsWithDaUpdate==0&& ...
    miniGate.maxPilotUpdatesPerTarget<=1&&miniGate.maxDaUpdatesPerTarget<=1&& ...
    isfinite(miniGate.baseEstimationTimeSec)&&isfinite(miniGate.proposedEstimationTimeSec);

twoLayer=auditOjcdTwoLayerSymbol(yt,pil,cov,.07,constellation);
results.twoLayerPipelinePass=isequal(size(twoLayer.traditional.Hdata),[D 2 2])&& ...
    isequal(size(twoLayer.ojcd.Hdata),[D 2 2])&&isequal(size(twoLayer.finalExtrinsicLlr),[D 2 4])&& ...
    ~any(isnan(twoLayer.finalExtrinsicLlr(:)))&&~any(isinf(twoLayer.finalExtrinsicLlr(:)));

results.rollbackDenominatorPass=auditComputeEpRollbackRate(2,10)==.2;
twoLayerPadding=auditOjcdTwoLayerSymbol(yt,pil,cov,.07,constellation,validDataMask=validMask);
expectedFull=D*2*cfg.epIterations;expectedMasked=nnz(validMask)*2*cfg.epIterations;
results.paddingCandidateDenominatorPass=twoLayerPadding.epPrecisionCandidateCountJcd1==expectedMasked&& ...
    twoLayerPadding.epPrecisionCandidateCountJcd2==expectedMasked&&twoLayerPadding.epPrecisionCandidateCountJcd1<expectedFull;
forcedJcd1=auditOjcdTwoLayerSymbol(yt,pil,cov,.07,constellation,forceNegativePrecisionIterationJcd1=1);
forcedJcd2=auditOjcdTwoLayerSymbol(yt,pil,cov,.07,constellation,forceNegativePrecisionIterationJcd2=1);
results.jcdLayerSeparationPass=forcedJcd1.epNegativePrecisionRollbackCountJcd1>twoLayer.epNegativePrecisionRollbackCountJcd1&& ...
    forcedJcd1.epNegativePrecisionRollbackCountJcd2==twoLayer.epNegativePrecisionRollbackCountJcd2&& ...
    forcedJcd2.epNegativePrecisionRollbackCountJcd2>twoLayer.epNegativePrecisionRollbackCountJcd2&& ...
    forcedJcd2.epNegativePrecisionRollbackCountJcd1==twoLayer.epNegativePrecisionRollbackCountJcd1;
results.iterationAccountingPass=sum(twoLayer.precisionCandidateCountByIterationJcd1)==twoLayer.epPrecisionCandidateCountJcd1&& ...
    sum(twoLayer.rollbackCountByIterationJcd1)==twoLayer.epNegativePrecisionRollbackCountJcd1&& ...
    sum(twoLayer.precisionCandidateCountByIterationJcd2)==twoLayer.epPrecisionCandidateCountJcd2;
results.streamAccountingPass=sum(twoLayer.precisionCandidateCountByStreamJcd1)==twoLayer.epPrecisionCandidateCountJcd1&& ...
    sum(twoLayer.rollbackCountByStreamJcd1)==twoLayer.epNegativePrecisionRollbackCountJcd1&& ...
    sum(twoLayer.precisionCandidateCountByStreamJcd2)==twoLayer.epPrecisionCandidateCountJcd2;
results.zeroCandidateRatePass=auditComputeEpRollbackRate(0,0)==0&&isfinite(auditComputeEpRollbackRate(0,0));

known=struct('conditionNumber',(1:100)','reciprocalConditionNumber',1./(1:100)', ...
    'minEigenvalueHermitianPart',(1:100)','minimumCholeskyPivot',(1:100)', ...
    'regularizationTriggered',[false(99,1);true],'regularizationLoading',[zeros(99,1);.25], ...
    'solverFailure',false(100,1),'nonFiniteMatrix',false(100,1),'nonFiniteSolution',false(100,1));
knownSummary=auditSummarizeOjcdConditionDiagnostics(known);
results.conditionQuantilePass=abs(knownSummary.conditionMedian-50.5)<1e-12&&abs(knownSummary.conditionP90-90.1)<1e-12&&abs(knownSummary.conditionP95-95.05)<1e-12&&abs(knownSummary.conditionP99-99.01)<1e-12&&knownSummary.conditionMaximum==100;
results.regularizationAuditPass=knownSummary.regularizationCount==1&&abs(knownSummary.regularizationRate-.01)<1e-12&&knownSummary.maximumRegularizationLoading==.25;
nonfinite=known;nonfinite.conditionNumber(2)=NaN;nonfinite.reciprocalConditionNumber(3)=Inf;nonfinite.minEigenvalueHermitianPart(4)=NaN;nonfinite.minimumCholeskyPivot(5)=NaN;nonfinite.nonFiniteMatrix(2)=true;nonfinite.nonFiniteSolution(3)=true;nonfinite.solverFailure(4)=true;
nonfiniteSummary=auditSummarizeOjcdConditionDiagnostics(nonfinite);
results.nonfiniteAuditPass=nonfiniteSummary.nonFiniteConditionCount==1&&nonfiniteSummary.nonFiniteRcondCount==1&&nonfiniteSummary.nonFiniteEigenvalueCount==1&&nonfiniteSummary.nonFiniteCholeskyPivotCount==1&&nonfiniteSummary.nonFiniteMatrixCount==1&&nonfiniteSummary.nonFiniteSolutionCount==1&&nonfiniteSummary.solverFailureCount==1;
diagnosticConfig=auditOjcdDiagnostic20Config(cfg);
results.diagnostic20ConfigPass=diagnosticConfig.packetCountPerCondition==20&& ...
    isequal(diagnosticConfig.payloadSymbols,cfg.symbolsPerCodeword*[1 3])&& ...
    diagnosticConfig.masterSeed==cfg.ojcdMiniMasterSeed&&numel(diagnosticConfig.methods)>=4&& ...
    endsWith(diagnosticConfig.outputDirectory,fullfile('results_three_layer_validation','ojcd_baseline_diagnostic20'));
schema=auditOjcdDiagnostic20Schema();fake=struct();schemaNames=fieldnames(schema);
for schemaIndex=1:numel(schemaNames),columns=schema.(schemaNames{schemaIndex});values=cell(1,numel(columns));for columnIndex=1:numel(columns),values{columnIndex}=0;end;fake.(schemaNames{schemaIndex})=cell2table(values,'VariableNames',columns);end
fake.packet.method="fake";fake.summary.method="fake";fake.paired.methodA="A";fake.paired.methodB="B";fake.paired.metric="metric";fake.hash.method="fake";fake.rollback.aggregationLevel="packet_total";fake.rollback.jcdLayer="ALL";
try
    auditValidateOjcdDiagnostic20Tables(fake,1,1);results.diagnostic20SchemaPass=true;
catch
    results.diagnostic20SchemaPass=false;
end

rollbackDetail=struct( ...
    'candidateJcd1',twoLayer.epPrecisionCandidateCountJcd1, ...
    'rollbackJcd1',twoLayer.epNegativePrecisionRollbackCountJcd1, ...
    'candidateJcd2',twoLayer.epPrecisionCandidateCountJcd2, ...
    'rollbackJcd2',twoLayer.epNegativePrecisionRollbackCountJcd2, ...
    'candidateMatrixJcd1',twoLayer.precisionCandidateCountByIterationStreamJcd1, ...
    'rollbackMatrixJcd1',twoLayer.rollbackCountByIterationStreamJcd1, ...
    'candidateMatrixJcd2',twoLayer.precisionCandidateCountByIterationStreamJcd2, ...
    'rollbackMatrixJcd2',twoLayer.rollbackCountByIterationStreamJcd2);
rollbackAudit=auditBuildOjcdRollbackAuditTable(rollbackDetail,17,3,cfg.epIterations);
conditionAudit=auditBuildOjcdConditionAuditRow(knownSummary,17,3);
layerTotals=rollbackAudit(rollbackAudit.aggregationLevel=="layer_total",:);
packetTotal=rollbackAudit(rollbackAudit.aggregationLevel=="packet_total",:);
results.diagnostic20ArtifactBuilderPass=height(rollbackAudit)==4*cfg.epIterations+3&& ...
    height(layerTotals)==2&&height(packetTotal)==1&&height(conditionAudit)==1&& ...
    packetTotal.precisionCandidateCount==sum(layerTotals.precisionCandidateCount)&& ...
    packetTotal.negativePrecisionRollbackCount==sum(layerTotals.negativePrecisionRollbackCount)&& ...
    isempty(setdiff(schema.rollback,rollbackAudit.Properties.VariableNames))&& ...
    isempty(setdiff(schema.condition,conditionAudit.Properties.VariableNames));

folder=fullfile(root,'audit_three_layer_helpers','ojcd_baseline');files=dir(fullfile(folder,'*.m'));text='';
for i=1:numel(files),text=[text fileread(fullfile(folder,files(i).name))];end %#ok<AGROW>
codeOnly=regexprep(text,'%[^\r\n]*','');
results.noExplicitInv=isempty(regexp(codeOnly,'(?<![A-Za-z])inv\s*\(','once'));
tests=[results.epNoiselessPass results.epHighNoisePass results.rollbackPass results.posteriorPass ...
    results.traditionalPass results.mjcdOjcdPass results.zeroErrorPass results.varianceInfluencePass ...
    results.truthLeakagePass results.causalityPass results.paddingPass results.sameCsiEpPass ...
    results.miniTensorInterfacePass results.twoLayerPipelinePass results.rollbackDenominatorPass ...
    results.paddingCandidateDenominatorPass results.jcdLayerSeparationPass results.iterationAccountingPass ...
    results.streamAccountingPass results.zeroCandidateRatePass results.conditionQuantilePass ...
    results.regularizationAuditPass results.nonfiniteAuditPass results.diagnostic20ConfigPass ...
    results.diagnostic20SchemaPass results.diagnostic20ArtifactBuilderPass results.noExplicitInv];
results.allTestsPassed=all(tests);
auditWriteOjcdImplementationAudit(cfg,results);
assert(results.allTestsPassed,'OJCD baseline deterministic self-test failed. See audit report.');
fprintf('OJCD baseline deterministic self-test PASS. MJCD/OJCD relative difference %.3g.\n',results.mjcdOjcdRelativeDifference);
end
