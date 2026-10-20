function results=auditCovarianceAwareSnrPairedLocalization20Selftest(root)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20SELFTEST Deterministic statistics and tiny resume tests.
results.brackets=localBracketTests();[lo,hi]=auditWilsonBinomialInterval(6,60,.95);
results.wilson=lo<.1&&hi>.1&&abs(lo-0.04635)<.002&&abs(hi-0.2015)<.003;
results.trends=localTrendTest();cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);
results.alias=localAlias(cfg);results.resume=localResume(root);
assert(all(structfun(@logical,results)),'Paired localization20 self-test failed.');
fprintf('paired localization20 self-test PASS: bracket A-F, Wilson, trend, alias, checkpoint/resume.\n');
end
function pass=localBracketTests()
method="M";make=@(b)localSummary(b,method);
A=auditPairedSnrStrictBrackets(make([.2 .05]),method,.1);
B=auditPairedSnrStrictBrackets(make([.1 .05]),method,.1);
C=auditPairedSnrStrictBrackets(make([.1 .1]),method,.1);
D=auditPairedSnrStrictBrackets(make([.3 .2]),method,.1);
E=auditPairedSnrStrictBrackets(make([.05 0]),method,.1);
F=auditPairedSnrStrictBrackets(make([.2 .05 .15]),method,.1);
pass=A.bracketFound&&B.exactGridHit&&~C.bracketFound&&C.targetPlateau&&~D.bracketFound&& ...
D.extensionSuggestion=="extend_higher_snr"&&~E.bracketFound&&E.extensionSuggestion=="extend_lower_snr"&&F.monotonicityWarning;
end
function S=localSummary(b,method)
n=numel(b);targetSnrDb=(1:n).';method=repmat(method,n,1);codewordBler=b(:);codewordBlerCiLower=max(0,codewordBler-.05);codewordBlerCiUpper=min(1,codewordBler+.05);
S=table(targetSnrDb,method,codewordBler,codewordBlerCiLower,codewordBlerCiUpper);
end
function pass=localTrendTest()
scenarioIndex=repmat((1:3).',2,1);targetSnrDb=[20*ones(3,1);24*ones(3,1)];method=repmat("M",6,1);
preLdpcBer=[.2;.2;.2;.1;.3;.2];softEvm=preLdpcBer;codewordErrorCount=[2;2;2;1;3;2];
T=table(targetSnrDb,method,scenarioIndex,preLdpcBer,softEvm,codewordErrorCount);
S=table([20;24],["M";"M"],[.2;.2],[.2;.2],[2/3;2/3],'VariableNames',{'targetSnrDb','method','meanPreLdpcBer','meanSoftEvm','codewordBler'});
[P,R]=auditPairedSnrTrendTables(T,S,"M");x=P(P.metric=="preLdpcBer",:);pass=x.improvingScenarioCount==1&&x.worseningScenarioCount==1&&x.tiedScenarioCount==1&&~R.monotonicityWarning(1);
end
function pass=localAlias(cfg)
pilot=complex(zeros(cfg.NFFT,1,2,2,'single'));for k=1:cfg.NFFT,pilot(k,1,:,:)=single(eye(2));end
bits=zeros(2*numel(cfg.data),4);for q=1:size(bits,1),bits(q,:)=bitget(mod(q-1,16),4:-1:1);end
x=reshape(ofdm.qam16ModBits(bits),2,[]);received=complex(zeros(numel(cfg.data),1,2,'single'));
for d=1:numel(cfg.data),received(d,1,:)=single(x(:,d));end
online=struct('pilotObservation',pilot,'receivedData',received,'validDataMask',true(numel(cfg.data),1),'noiseVar',cfg.noiseVar,'rho',cfg.rho);
a=auditMechanismRunSingleEstimator(cfg,online,"FixedRadius3LsCovOnlyCausal_EP");b=auditMechanismRunSingleEstimator(cfg,online,"CovarianceAwareLocalDAKalmanCausal_EP");
pass=isequaln(a.Hhat,b.Hhat)&&isequaln(a.finalState,b.finalState)&&isequaln(a.finalCovariance,b.finalCovariance);
end
function pass=localResume(root)
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);cfg.masterSeed=2026072503;cfg.bootstrapSeed=2026072504;
cfg.SNRdBGrid=20;cfg.scenarioCount=1;resumeDir=[tempname '_paired_resume'];refusalDir=[tempname '_paired_refusal'];
cleanup=onCleanup(@()localCleanup({resumeDir,refusalDir}));
first=auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,resumeDir,stopAfterScenarios=1,testMode=true);
schema=auditCovarianceAwareSnrPairedLocalization20Schema();interrupted=first.status=="interrupted_for_test"&&~isfile(fullfile(resumeDir,schema.files.complete));
resumed=auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,resumeDir,resume=true,testMode=true);
noDuplicates=height(unique(resumed.packetTable(:,{'scenarioIndex','targetSnrDb','method'}),'rows'))==height(resumed.packetTable);
preserved=isequaln(first.packetTable,resumed.packetTable);mkdir(refusalDir);f=fopen(fullfile(refusalDir,'keep.txt'),'w');fprintf(f,'keep');fclose(f);refused=false;
try
    auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,refusalDir,testMode=true);
catch
    refused=true;
end
pass=interrupted&&noDuplicates&&preserved&&isfile(fullfile(resumeDir,schema.files.complete))&&refused;
end
function localCleanup(paths),for i=1:numel(paths),if exist(paths{i},'dir'),rmdir(paths{i},'s');end,end,end
