function results = auditQualityAwareMechanismDeterministicSelftest(root)
%AUDITQUALITYAWAREMECHANISMDETERMINISTICSELFTEST Formula and isolation gates.
cfg=auditQualityAwareMechanismConfig(root);h=(1:8)'/10;P=diag(0.2+(1:8)/100);
z=h+[.1;-.2;.05;-.1;.2;-.05;.15;-.1];Rlegacy=0.3*eye(8);Rls=diag(0.1+(1:8)/100);

a=auditMechanismFixedR3Update(h,P,z,Rlegacy,[],[],"A",cfg);
selection=struct('accepted',true,'candidate',struct('zDa',z,'Rda',Rlegacy));
[hDirect,PDirect,directAudit]=auditQualityAwareDaKalmanUpdate(h,P,selection,Rlegacy,cfg);
results.aStateRegression=localClose(a.hFinal,hDirect)&&localClose(a.PFinal,PDirect);
results.aCounterRegression=a.updateCount==directAudit.daUpdateCount&&isnan(a.nis);

[zLow,zMid,zHigh]=localNisVectors();unitP=eye(8);unitR=eye(8);zero=zeros(8,1);
aLow=auditMechanismFixedR3Update(zero,unitP,zLow,unitR,[],[],"A",cfg);
bLow=auditMechanismFixedR3Update(zero,unitP,zLow,unitR,[],[],"B",cfg);
bHigh=auditMechanismFixedR3Update(zero,unitP,zHigh,unitR,[],[],"B",cfg);
results.bLowEqualsA=localClose(bLow.hFinal,aLow.hFinal)&&localClose(bLow.PFinal,aLow.PFinal)&&bLow.nis<cfg.chiSquareHardThresholdDof8P999;
results.bHardReject=bHigh.hardRejected&&bHigh.updateCount==0&&isequal(bHigh.hFinal,zero)&&isequal(bHigh.PFinal,unitP);
results.bNoInflation=bLow.nisInflationFactor==1&&localClose(bLow.Rda,unitR);

cLow=auditMechanismFixedR3Update(zero,unitP,zLow,unitR,[],[],"C",cfg);
cMid=auditMechanismFixedR3Update(zero,unitP,zMid,unitR,[],[],"C",cfg);
cHigh=auditMechanismFixedR3Update(zero,unitP,zHigh,unitR,[],[],"C",cfg);
results.cLowInflationOne=abs(cLow.nisInflationFactor-1)<1e-12;
results.cMidInflationFormula=abs(cMid.nisInflationFactor-cMid.nis/8)<1e-12&&cMid.nis>8&&cMid.nis<cfg.chiSquareHardThresholdDof8P999;
results.cHardReject=cHigh.hardRejected&&cHigh.updateCount==0;

d=auditMechanismFixedR3Update(h,P,z,[],Rls,[],"D",cfg);
results.dUsesOnlyRls=localClose(d.Rda,Rls)&&isnan(d.nis)&&isnan(d.nisInflationFactor)&&isnan(d.decisionInflationFactor);
eLow=auditMechanismFixedR3Update(zero,unitP,zLow,[],unitR,[],"E",cfg);
eHigh=auditMechanismFixedR3Update(zero,unitP,zHigh,[],unitR,[],"E",cfg);
results.eAddsOnlyHardReject=eLow.updateCount==1&&localClose(eLow.Rda,unitR)&&eHigh.hardRejected;
fMid=auditMechanismFixedR3Update(zero,unitP,zMid,[],unitR,[],"F",cfg);
results.fAddsOnlyNisInflation=abs(fMid.nisInflationFactor-fMid.nis/8)<1e-12&&localClose(fMid.Rda,(fMid.nis/8)*unitR);

[candidate,hSeed,PSeed]=localQualityCandidate(cfg);
g=auditMechanismFixedR3Update(hSeed,PSeed,candidate.zDa,[],candidate.Rls,candidate.Rda,"G",cfg);
selected=struct('accepted',true,'candidate',candidate);
[hFinal,PFinal,gAudit]=auditQualityAwareDaKalmanUpdate(hSeed,PSeed,selected,candidate.Rda,cfg);
results.gFinalRadius3Rda=localClose(g.Rda,candidate.Rda)&&localClose(candidate.Rdecision,candidate.decisionInflationFactor*candidate.Rls);
results.gFinalRadius3State=localClose(g.hFinal,hFinal)&&localClose(g.PFinal,PFinal)&&g.updateCount==gAudit.daUpdateCount;

containers=arrayfun(@(index)struct('owner',index,'state',index*ones(8,1),'P',index*eye(8)),1:10,'UniformOutput',false);
before=containers;containers{1}.state(1)=999;
results.branchStateIsolation=all(cellfun(@(x,y)isequal(x,y),containers(2:end),before(2:end)));
results.singleUpdateUpperBound=all([a.updateCount,bLow.updateCount,bHigh.updateCount,cLow.updateCount,cMid.updateCount,cHigh.updateCount,d.updateCount,eLow.updateCount,eHigh.updateCount,fMid.updateCount,g.updateCount]<=1);
[results.tenMethodTensorInterface,results.offlineMetricTensorInterface,results.aFrozenEstimatorRegression]=localTensorInterfaces(cfg);

paddingCandidate=localPaddingCandidate(cfg);
results.paddingExcludedFromLs=paddingCandidate.candidateFeasible&&~ismember(4,paddingCandidate.sampleIndices);
results.paddingExcludedFromMetrics=localPaddingMetricCheck();

xTrue=[1+1i,1-1i,-1+1i,-1-1i];xSoft=xTrue+[.1,-.2i,.1+.1i,-.1];xHard=xTrue+[0,0,2,0];
softExpected=sqrt(sum(abs(xSoft-xTrue).^2)/sum(abs(xTrue).^2));hardExpected=sqrt(sum(abs(xHard-xTrue).^2)/sum(abs(xTrue).^2));
results.softEvmFormula=abs(softExpected-sqrt(.08/8))<1e-12;
results.hardEvmFormula=abs(hardExpected-sqrt(4/8))<1e-12;
results.evmEffectiveSinrFormula=abs(10*log10(sum(abs(xTrue).^2)/sum(abs(xSoft-xTrue).^2))+10*log10(softExpected^2))<1e-12;

[streamNmse,worst,best]=localStreamNmse();
results.streamNmseFormula=localClose(streamNmse,[.01,.04])&&abs(worst-.04)<1e-12&&abs(best-.01)<1e-12;
values=(1:10)';results.percentileFormula=abs(auditDeterministicPercentile(values,.90)-9.1)<1e-12&&abs(auditDeterministicPercentile(values,.95)-9.55)<1e-12&&abs(auditDeterministicPercentile(values,.99)-9.91)<1e-12;
[mask1,mask2]=localDeepFadeMasks();results.deepFadeMask=isequal(mask1,[true false false false false false false false false false]')&&isequal(mask1,mask2);
results.pearsonFormula=abs(auditPearsonCorrelation((1:5)',(2:2:10)')-1)<1e-12&&isnan(auditPearsonCorrelation(ones(5,1),(1:5)'));
results.spearmanTiedRank=abs(auditSpearmanCorrelation([1;2;2;4],[1;2;3;4])-.948683298050514)<1e-12&&isnan(auditSpearmanCorrelation(ones(4,1),(1:4)'));

onlineState=struct('hFinal',g.hFinal,'PFinal',g.PFinal,'llr',[1;-1],'codewordPass',true);saved=onlineState;truthPerturbation=sum(abs(2*xTrue-xSoft).^2); %#ok<NASGU>
results.onlineOfflineIsolation=isequaln(onlineState,saved);
results.onlineInterfacesExcludeTruth=localOnlineInterfaceIsolation();

formalExisted=exist(cfg.mechanismOutput,'dir')==7;temporary=[tempname '_mechanism_selftest'];cleanup=onCleanup(@()localCleanup(temporary));
dry=auditQualityAwareMechanismDiagnostic20(root,'dryRun',true,'outputDirectory',temporary);schema=auditQualityAwareMechanismSchema();names=fieldnames(schema);
results.dryRunSchema=all(cellfun(@(name)isequal(dry.tables.(name).Properties.VariableNames,schema.(name)),names));
results.dryRunIsolation=dry.dryRun&&dry.randomPhysicalPacketCount==0&&dry.methodCount==10&&((exist(cfg.mechanismOutput,'dir')==7)==formalExisted);
results.dryRunCleanup=exist(dry.outputDirectory,'dir')~=7;
results.frozenPairingSchema=dry.preflight.frozenPairingSchemaPass&&height(dry.preflight.frozenPairingTable)==440;
hashTests=localFrozenHashTests(cfg.frozenHashAbsoluteTolerance);results.frozenHashExact=hashTests(1);results.frozenHashCsvTolerance=hashTests(2);results.frozenHashRejectsMismatch=hashTests(3);results.frozenHashRejectsSeedMismatch=hashTests(4);
results.overwriteGate=localOverwriteGate(root,cfg);
results.protectedHashes=dry.preflight.protectedHashesPass;
results.legacyRegressionEvidence=dry.preflight.deterministicReportsPass&&dry.preflight.mjcdOjcdRelativeDifference<=1e-8;

fields=fieldnames(results);passed=cellfun(@(name)logical(results.(name)),fields);
assert(all(passed),'Mechanism deterministic self-test failed: %s',strjoin(string(fields(~passed)),', '));
fprintf('Quality-aware mechanism deterministic self-test PASS: %d/%d; random packets=0.\n',nnz(passed),numel(passed));
end

function [low,mid,high]=localNisVectors()
low=ones(8,1);mid=2*ones(8,1);high=sqrt(7.5)*ones(8,1);
end

function [candidate,h,P]=localQualityCandidate(cfg)
H=[1+.1i,.2-.1i;-.3+.2i,.9-.2i];X=[1,0,1,1i,-1,1,-1i;0,1,1,-1,1i,-1i,1];Y=H*X;
L=10*ones(4,2,size(X,2));h=auditChannelMatrixToFeatureVector(H);P=.2*eye(8);
candidate=auditBuildQualityAwareLocalDaCandidate(X,Y,L,4,true(1,size(X,2)),3,h,P,cfg.noiseVar,cfg);
assert(candidate.candidateFeasible,'Deterministic radius-3 candidate unexpectedly infeasible.');
end

function candidate=localPaddingCandidate(cfg)
H=[1,.2;-.1,.8];X=[1,0,1,100,1;0,1,1,100,-1];Y=H*X;Y(:,4)=1e6;
L=10*ones(4,2,5);candidate=auditBuildQualityAwareLocalDaCandidate(X,Y,L,3,[true true true false true],2,auditChannelMatrixToFeatureVector(H),eye(8),cfg.noiseVar,cfg);
end

function pass=localPaddingMetricCheck()
truth=[1,2,3,1e6];estimate=[1.1,1.9,3.2,-1e6];valid=[true true true false];
withMask=sum(abs(estimate(valid)-truth(valid)).^2);manual=.01+.01+.04;pass=abs(withMask-manual)<1e-12;
end

function [nmse,worst,best]=localStreamNmse()
truth=ones(2,3,2);estimate=truth;estimate(:,:,1)=1.1;estimate(:,:,2)=1.2;nmse=zeros(1,2);
for stream=1:2
    errorValue=estimate(:,:,stream)-truth(:,:,stream);reference=truth(:,:,stream);
    nmse(stream)=sum(abs(errorValue(:)).^2)/sum(abs(reference(:)).^2);
end
worst=max(nmse);best=min(nmse);
end

function [first,second]=localDeepFadeMasks()
gain=(1:10)';threshold=auditDeterministicPercentile(gain,.10);first=gain<=threshold;second=gain<=auditDeterministicPercentile(gain,.10);
end

function pass=localOnlineInterfaceIsolation()
folder=fileparts(mfilename('fullpath'));names={'auditMechanismRunSingleEstimator.m','auditMechanismOnlineReceive.m'};pass=true;
for index=1:numel(names),text=fileread(fullfile(folder,names{index}));firstLine=extractBefore(text,newline);pass=pass&&~contains(lower(firstLine),'htrue')&&~contains(lower(firstLine),'qamtrue')&&~contains(lower(firstLine),'codedbits');end
end

function [estimatorPass,metricPass,aRegression]=localTensorInterfaces(cfg)
N=2;D=numel(cfg.data);observation=complex(zeros(cfg.NFFT,N,2,2,'single'));received=complex(zeros(D,N,2,'single'));
constellation=qammod((0:15).',16,'UnitAveragePower',true);symbols=complex(zeros(2,D));
for dataIndex=1:D,symbols(:,dataIndex)=constellation([mod(dataIndex-1,16)+1;mod(3*dataIndex,16)+1]);end
for symbolIndex=1:N
    for subcarrier=1:cfg.NFFT
        observation(subcarrier,symbolIndex,:,:)=single([1+.001*subcarrier+.01i*symbolIndex,.12-.03i;-.08+.02i,.85-.001*subcarrier-.01i*symbolIndex]);
    end
    for dataIndex=1:D
        received(dataIndex,symbolIndex,:)=single(squeeze(observation(cfg.data(dataIndex),symbolIndex,:,:))*symbols(:,dataIndex));
    end
end
valid=true(D,N);valid(end,end)=false;resourceMask=repmat(reshape(valid,1,D,N),cfg.bitsPerQam*cfg.NT,1,1);usefulMask=resourceMask(:);
online=struct('pilotObservation',observation,'receivedData',received,'validDataMask',valid,'validReMask',valid, ...
    'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',N,'nCodeword',0,'usefulBitMask',usefulMask);
estimatorPass=true;baseEstimate=[];aEstimate=[];
for method=cfg.mechanismMethods
    estimate=auditMechanismRunSingleEstimator(cfg,online,method);
    estimatorPass=estimatorPass&&isequal(size(estimate.Hhat),[cfg.NFFT,N,2,2])&&all(isfinite(estimate.Hhat(:)))&& ...
        estimate.futureSymbolReadCount==0&&estimate.testTruthOnlineUseCount==0;
    if method=="BaseKalmanCausal_EP",baseEstimate=estimate;end
    if method=="FixedRadius3Causal_EP",aEstimate=estimate;end
end
receiver=auditMechanismOnlineReceive(cfg,online,baseEstimate.Hhat,baseEstimate.onlineEstimationRuntimeSeconds);
qamTrue=repmat(reshape(symbols,2,D,1),1,1,N);codedBits=false(nnz(usefulMask),1);
metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,baseEstimate.Hhat,observation,qamTrue,codedBits,valid);
metricPass=isfinite(metric.csiNmse)&&isfinite(metric.preLdpcBer)&&metric.deepFadeReCount>0&& ...
    isfinite(metric.softEvmRms)&&isfinite(metric.offlineAuditRuntimeSeconds)&&metric.offlineAuditRuntimeSeconds>=0;
packet=struct('Npayload',N,'obs',observation,'y',received,'qam',qamTrue,'validReMask',valid);
legacy=auditQualityAwareLegacyCausalEstimates(cfg,packet,3);
difference=max(abs(double(aEstimate.Hhat(:))-double(legacy.HfixedRadius3(:))));
scale=max(1,max(abs(double(legacy.HfixedRadius3(:)))));
aRegression=difference<=eps('single')*scale&&aEstimate.audit.daUpdateCount==legacy.fixedAudit3.accepted;
end

function pass=localOverwriteGate(root,cfg)
path=[tempname '_mechanism_overwrite'];mkdir(path);cleanup=onCleanup(@()localCleanup(path));file=fopen(fullfile(path,'quality_aware_mechanism_packet_level.csv'),'w');fclose(file);pass=false;
try
    auditQualityAwareMechanismPreflight(root,cfg,path);
catch exception
    pass=contains(exception.message,'Refusing to overwrite');
end
end

function tests=localFrozenHashTests(tolerance)
names={'informationBitsHash','transmitBitsHash','codedBitsHash','qamSymbolsHash','paddingMaskHash','channelHash','noiseHash','receivedSignalHash','pilotObservationHash'};
values=num2cell(100+(1:numel(names)));tableValues=[{169,1,1,"method",20360720,20360721} values];frozen=cell2table(tableValues,'VariableNames',[{'payloadSymbols','nCodeword','packetIndex','method','conditionSeed','packetSeed'} names]);
hashes=struct();for index=1:numel(names),hashes.(names{index})=values{index};end;packet=struct('Npayload',169,'hashes',hashes);
exact=auditVerifyFrozenPacketHashes(packet,1,20360720,20360721,frozen,tolerance);tests(1)=exact.exactMatchCount==9&&exact.absoluteToleranceMatchCount==0;
packet.hashes.informationBitsHash=packet.hashes.informationBitsHash+tolerance/2;rounded=auditVerifyFrozenPacketHashes(packet,1,20360720,20360721,frozen,tolerance);tests(2)=rounded.exactMatchCount==8&&rounded.absoluteToleranceMatchCount==1;
tests(3)=localExpectHashFailure(packet,1,20360720,20360721,frozen,tolerance/4);tests(4)=localExpectHashFailure(packet,1,20360720,20360722,frozen,tolerance);
end

function pass=localExpectHashFailure(packet,packetIndex,conditionSeed,packetSeed,frozen,tolerance)
pass=false;
try
    auditVerifyFrozenPacketHashes(packet,packetIndex,conditionSeed,packetSeed,frozen,tolerance);
catch
    pass=true;
end
end

function pass=localClose(a,b)
scale=max(1,max(abs(b(:))));pass=isequal(size(a),size(b))&&max(abs(a(:)-b(:)))<=1e-12*scale;
end

function localCleanup(path)
if exist(path,'dir'),rmdir(path,'s');end
end
