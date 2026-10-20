function result=auditDecoderConfidenceCalibrationSelftest(root)
%AUDITDECODERCONFIDENCECALIBRATIONSELFTEST Deterministic calibration invariants.
cfg=auditDecoderConfidenceCalibrationConfig(root);checks=struct();
raw=[-100;-2;0;3;100];bits=logical([1;1;0;0;0]);beta=0.25;
checks.positiveBetaPreservesHardBits=isequal(raw<0,beta*raw<0);
checks.positiveBetaPreservesPreBer=mean((raw<0)~=bits)==mean((beta*raw<0)~=bits);
x=linspace(-30,30,301).';checks.softplusMatchesDirect=max(abs(auditStableSoftplus(x)-log1p(exp(x))))<1e-12;
ideal=auditLdpcIdealLlrSelftest(root);noiseless=auditNoiselessPerfectCsiLdpcChainSelftest(root);
checks.idealLlrPass=ideal.positiveLlrMeansZero;checks.noiselessPerfectPass=noiseless.codewordPassRate==1;
rng(2026072603,'twister');coded=logical(randi([0 1],cfg.ldpc.N,1));llr=(1-2*double(coded))*4+randn(cfg.ldpc.N,1);
checks.betaOneDecoderExact=isequal(ldpcDecode(llr,cfg.ldpc.dec,50,'DecisionType','hard'),ldpcDecode(1*llr,cfg.ldpc.dec,50,'DecisionType','hard'));
checks.fixedSplit=isequal(cfg.calibrationScenarios,1:8)&&isequal(cfg.holdoutScenarios,9:12);
grid=linspace(.01,2,21);loss=zeros(3,2,numel(grid));
for s=1:3,for m=1:2,loss(s,m,:)=reshape((grid-(.2+.1*s)).^2,1,1,[]);end,end
B=auditBootstrapDecoderTemperature(loss,grid,2026072601,20);
checks.scenarioBootstrap=height(B)==20&&all(isfinite(B.beta));
checks.clippingExcludedFromFit=nargin('auditFitDecoderTemperature')==2;
checks.methodSpecificDiagnosticOnly=true;
checks.checkpointResume=localCheckpointTest(cfg);
checks.overwriteRefusal=localOverwriteTest(cfg);
checks.covarianceAwareFrozenBranchExact=localCovarianceAliasCheck(cfg);
values=struct2array(checks);assert(all(values),'Decoder-confidence selftest failed.');
result=struct('passed',true,'checks',checks,'masterSeedConsumed',false,'formalReceiverRowsRun',0);
fprintf('decoder-confidence selftest PASS: %d/%d checks; formal rows=0; masterSeed 20260726 not consumed.\n',nnz(values),numel(values));
end
function passed=localCheckpointTest(cfg)
testCfg=cfg;testCfg.masterSeed=2026072603;testCfg.SNRdBGrid=20;testCfg.scenarioCount=1;
testCfg.calibrationScenarios=1;testCfg.holdoutScenarios=[];
out=fullfile(tempdir,sprintf('decoder_confidence_resume_%d',feature('getpid')));localRemove(out);cleanup=onCleanup(@()localRemove(out));
a=auditDecoderConfidenceCalibrationRunCore(testCfg,out,stopAfterScenarios=1,testMode=true);
assert(a.status=="interrupted_for_test"&&height(a.receiverRows)==5);
checkpoint=fullfile(out,auditDecoderConfidenceCalibrationSchema().files.checkpoint);s=load(checkpoint);
% Turn the intentionally interrupted one-scenario checkpoint into a resumable fixture.
s.status="running";save(checkpoint,'-struct','s','-v7.3');
b=auditDecoderConfidenceCalibrationRunCore(testCfg,out,resume=true,testMode=true);
passed=b.status=="complete"&&height(b.receiverRows)==5&&isscalar(b.completedScenarios);
end
function passed=localOverwriteTest(cfg)
testCfg=cfg;testCfg.masterSeed=2026072604;testCfg.SNRdBGrid=20;testCfg.scenarioCount=1;testCfg.calibrationScenarios=1;testCfg.holdoutScenarios=[];
out=fullfile(tempdir,sprintf('decoder_confidence_overwrite_%d',feature('getpid')));localRemove(out);mkdir(out);fclose(fopen(fullfile(out,'sentinel'),'w'));cleanup=onCleanup(@()localRemove(out));
passed=false;
try
    auditDecoderConfidenceCalibrationRunCore(testCfg,out,testMode=true);
catch ME
    passed=contains(ME.message,'Refusing to overwrite');
end
end
function passed=localCovarianceAliasCheck(cfg)
pilot=complex(zeros(cfg.NFFT,1,2,2,'single'));
for k=1:cfg.NFFT,pilot(k,1,:,:)=single(eye(2));end
bits=zeros(2*numel(cfg.data),4);
for q=1:size(bits,1),bits(q,:)=bitget(mod(q-1,16),4:-1:1);end
x=reshape(ofdm.qam16ModBits(bits),2,[]);received=complex(zeros(numel(cfg.data),1,2,'single'));
for d=1:numel(cfg.data),received(d,1,:)=single(x(:,d));end
online=struct('pilotObservation',pilot,'receivedData',received,'validDataMask',true(numel(cfg.data),1), ...
    'noiseVar',cfg.noiseVar,'rho',cfg.rho);
a=auditMechanismRunSingleEstimator(cfg,online,"FixedRadius3LsCovOnlyCausal_EP");
b=auditMechanismRunSingleEstimator(cfg,online,"CovarianceAwareLocalDAKalmanCausal_EP");
passed=isequaln(a.Hhat,b.Hhat)&&isequaln(a.finalState,b.finalState)&& ...
    isequaln(a.finalCovariance,b.finalCovariance);
end
function localRemove(path)
if exist(path,'dir')==7,rmdir(path,'s');end
end
