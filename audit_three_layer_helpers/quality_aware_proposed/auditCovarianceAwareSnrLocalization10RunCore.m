function result=auditCovarianceAwareSnrLocalization10RunCore(cfg,out,options)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10RUNCORE Paired SNR executor with atomic checkpoint.
arguments,cfg struct,out (1,:) char,options.resume (1,1) logical=false, ...
    options.stopAfterPackets (1,1) double=inf,options.testMode (1,1) logical=false,end
schema=auditCovarianceAwareSnrLocalization10Schema();assert(numel(cfg.methods)==5);
checkpointPath=fullfile(out,schema.files.checkpoint);
[T,completed]=localStart(out,checkpointPath,cfg,schema,options.resume);physicalDone=height(completed);
for si=1:numel(cfg.SNRdBGrid)
    snrDb=cfg.SNRdBGrid(si);conditionSeed=auditCovarianceAwareSnrConditionSeed(cfg.masterSeed,snrDb);
    for packetIndex=1:cfg.packetCountPerSnr
        if localCompleted(completed,snrDb,packetIndex),continue;end
        packetSeed=conditionSeed+packetIndex;rng(packetSeed,'twister');
        pointCfg=cfg;pointCfg.SNRdB=snrDb;pointCfg.noiseVar=10^(-snrDb/10);
        packet=auditQualityAwareMiniPacket(pointCfg,cfg.Ncodeword);
        packetRows=localRunPacket(pointCfg,packet,packetIndex,conditionSeed,packetSeed);
        localPacketGate(packetRows,cfg);T=[T;packetRows]; %#ok<AGROW>
        completed=[completed;table(snrDb,packetIndex,'VariableNames',{'SNRdB','packetIndex'})]; %#ok<AGROW>
        physicalDone=physicalDone+1;localSave(checkpointPath,cfg,schema,T,completed,"running",snrDb,packetIndex);
        fprintf('SNR localization checkpoint: SNR=%g packet=%d rows=%d\n',snrDb,packetIndex,height(T));
        if physicalDone>=options.stopAfterPackets
            result=struct('status',"interrupted_for_test",'packetTable',T,'outputDirectory',out);return;
        end
    end
end
artifacts=auditCovarianceAwareSnrLocalization10Finalize(cfg,out,T,options.testMode);
localSave(checkpointPath,cfg,schema,T,completed,"complete",completed.SNRdB(end),completed.packetIndex(end));
f=fopen(fullfile(out,schema.files.complete),'w');assert(f>=0);fprintf(f,'complete\n');fclose(f);
result=struct('status',"complete",'packetTable',T,'artifacts',artifacts, ...
    'randomPhysicalPacketCount',height(completed),'outputDirectory',out);
end

function rows=localRunPacket(cfg,p,packetIndex,conditionSeed,packetSeed)
online=struct('pilotObservation',p.obs,'receivedData',p.y,'validDataMask',p.validReMask, ...
    'validReMask',p.validReMask,'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',p.Npayload, ...
    'nCodeword',p.nCodeword,'usefulBitMask',p.usefulBitMask);
covariance=localCovariance(cfg);rows=cell(numel(cfg.methods),1);
for methodIndex=1:numel(cfg.methods)
    method=cfg.methods(methodIndex);audit=localEmptyAudit();authorizedTruth=0;solver=0;
    switch method
        case "BaseKalmanCausal_EP"
            estimate=auditMechanismRunSingleEstimator(cfg,online,method);Hhat=estimate.Hhat;audit=estimate.audit;
            receiver=auditMechanismOnlineReceive(cfg,online,Hhat,estimate.onlineEstimationRuntimeSeconds);solver=audit.solverFailureCount;
        case {"FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"}
            estimate=auditMechanismRunSingleEstimator(cfg,online,method);Hhat=estimate.Hhat;audit=estimate.audit;
            receiver=auditMechanismOnlineReceive(cfg,online,Hhat,estimate.onlineEstimationRuntimeSeconds);solver=audit.solverFailureCount;
        case "OJCD_LMMSE_EP_Adapted"
            ojcd=auditCovarianceAwareOjcdReceive(cfg,p,covariance);Hhat=ojcd.Hhat;receiver=ojcd.receiver;solver=ojcd.solverFailureCount;
        case "PerfectCSI_EP"
            Hhat=p.H;receiver=auditMechanismOnlineReceive(cfg,online,Hhat,0);authorizedTruth=1;
        otherwise
            error('Unknown frozen SNR-localization method: %s',method);
    end
    metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,Hhat,p.H,p.qam,p.codedBits,p.validReMask);
    metric.onlineRuntimeSeconds=receiver.onlineRuntimeSeconds;
    rows{methodIndex}=localRow(cfg,metric,audit,p,method,packetIndex,conditionSeed,packetSeed,solver,authorizedTruth,receiver);
end
rows=vertcat(rows{:});
end

function T=localRow(cfg,m,a,p,method,packetIndex,conditionSeed,packetSeed,solver,authorizedTruth,receiver)
schema=auditCovarianceAwareSnrLocalization10Schema();isDa=ismember(method,["FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"]);
decoded=m.totalCodewordCount;errors=decoded-m.passedCodewordCount;
values={cfg.experimentName,cfg.masterSeed,cfg.bootstrapSeed,cfg.SNRdB,cfg.fdHz,p.Npayload,p.nCodeword,packetIndex,method, ...
    conditionSeed,packetSeed,p.hashes.channelHash,p.hashes.receivedSignalHash,p.hashes.transmitBitsHash, ...
    p.hashes.paddingBitsHash,p.hashes.paddingSymbolsHash,nnz(~p.validReMask),m.csiNmse,m.worstStreamCsiNmse, ...
    m.p95ReNormalizedError,m.p99ReNormalizedError,m.deepFadeCsiNmse,m.preLdpcBer,NaN, ...
    double(m.codewordPassRate==1),m.codewordPassRate,errors,decoded,m.payloadGoodputMbps,m.softEvmRms, ...
    m.softEvmRms^2,m.onlineRuntimeSeconds+m.offlineAuditRuntimeSeconds,0,0,authorizedTruth,solver,0,0, ...
    localApplicable(a,'candidateFeasibleCount',isDa),localApplicable(a,'daUpdateCount',isDa), ...
    localApplicable(a,'noCandidateCount',isDa),localStat(a,'rdaTrace','mean',isDa), ...
    localStat(a,'rdaTrace','median',isDa),localStat(a,'minRlsEigenvalue','min',isDa), ...
    localStat(a,'rlsConditionNumber','max',isDa),localApplicable(a,'daUpdateCount',isDa), ...
    localApplicable(a,'daUpdateCount',isDa),0,0,0,0,0,0,0, ...
    double(method~="PerfectCSI_EP"),double(isDa),double(receiver.hasNaN),double(receiver.hasInf)};
T=cell2table(values,'VariableNames',cellstr(schema.packetLevel));
end

function value=localApplicable(a,name,yes)
if ~yes,value=0;return;end
if isfield(a,name),value=double(a.(name));else,value=0;end
end
function value=localStat(a,name,kind,yes)
if ~yes||~isfield(a,name),value=NaN;return;end
x=a.(name);x=x(isfinite(x));if isempty(x),value=NaN;else,value=feval(kind,x);end
end
function a=localEmptyAudit()
a=struct('candidateFeasibleCount',0,'daUpdateCount',0,'noCandidateCount',0,'pilotUpdateCount',0, ...
    'rdaTrace',NaN,'minRlsEigenvalue',NaN,'rlsConditionNumber',NaN,'solverFailureCount',0);
end
function covariance=localCovariance(cfg),loaded=load(cfg.covariancePath,'covariance');covariance=loaded.covariance;end

function localPacketGate(T,cfg)
assert(height(T)==numel(cfg.methods)&&numel(unique(T.method))==numel(cfg.methods));
hashes={'sharedHashH','sharedHashY','sharedHashTxBits','paddingBitHash','paddingSymbolHash','paddingReCount'};
for i=1:numel(hashes),assert(isscalar(unique(T.(hashes{i}))),'Pairing mismatch in %s.',hashes{i});end
assert(~any(T.hasNaN)&&~any(T.hasInf),'NaN/Inf hard gate failed.');
assert(all(T.legacySecondPassUseCount==0)&all(T.withinSymbolDaFeedbackEvents==0)& ...
    all(T.stateRestartsAfterSymbol1==0)&all(T.crossSubcarrierStatePropagationEvents==0));
assert(all(T.repeatedPilotUseCount==0)&all(T.rejectedTargetsWithDaUpdate==0)&all(T.paddingTargetsWithDaUpdate==0));
assert(all(T.maxPilotUpdatesPerTarget<=1)&all(T.maxDaUpdatesPerTarget<=1));
assert(all(T.solverFailureCount==0)&all(T.paddingDaUseCount==0)&all(T.sameSymbolFeedbackCount==0));
assert(all(T.futureSymbolReadCount==0));
ordinary=T.method~="PerfectCSI_EP";assert(all(T.testTruthOnlineUseCount(ordinary)==0));
end

function yes=localCompleted(keys,snrDb,index),yes=~isempty(keys)&&any(keys.SNRdB==snrDb&keys.packetIndex==index);end
function [T,keys]=localStart(out,path,cfg,schema,resume)
nonempty=false;if exist(out,'dir')==7,e=dir(out);nonempty=any(~ismember({e.name},{'.','..'}));end
if nonempty
    assert(resume,'Refusing to overwrite nonempty output directory: %s',out);
    assert(exist(path,'file')==2,'Resume requested but checkpoint is missing: %s',path);
    saved=load(path);localCheck(saved,cfg,schema);T=saved.packetTable;keys=saved.completedKeys;
else
    assert(~resume,'Resume requested but no checkpoint directory exists: %s',out);
    if exist(out,'dir')~=7,mkdir(out);end
    T=cell2table(cell(0,numel(schema.packetLevel)),'VariableNames',cellstr(schema.packetLevel));
    keys=table([],[],'VariableNames',{'SNRdB','packetIndex'});
end
end
function localCheck(s,cfg,schema)
assert(s.masterSeed==cfg.masterSeed&&s.bootstrapSeed==cfg.bootstrapSeed&& ...
    isequal(s.methods,cfg.methods)&&isequal(s.SNRdBGrid,cfg.SNRdBGrid)&& ...
    s.packetCountPerSnr==cfg.packetCountPerSnr&&s.Npayload==cfg.Npayload&& ...
    string(s.schemaVersion)==schema.version,'Checkpoint configuration mismatch.');
assert(string(s.status)~="complete",'Checkpoint already represents a complete run.');rng(s.rngState);
end
function localSave(path,cfg,schema,packetTable,completedKeys,status,snrDb,index)
tmp=[char(path) '.tmp'];masterSeed=cfg.masterSeed;bootstrapSeed=cfg.bootstrapSeed;methods=cfg.methods;
SNRdBGrid=cfg.SNRdBGrid;packetCountPerSnr=cfg.packetCountPerSnr;Npayload=cfg.Npayload;schemaVersion=schema.version;
rngState=rng;checkpointVersion="1.0";lastCompletedSnrDb=snrDb;lastCompletedPacketIndex=index;
save(tmp,'cfg','masterSeed','bootstrapSeed','methods','SNRdBGrid','packetCountPerSnr','Npayload','schemaVersion', ...
    'packetTable','completedKeys','status','rngState','checkpointVersion','lastCompletedSnrDb','lastCompletedPacketIndex','-v7.3');
[ok,message]=movefile(tmp,path,'f');assert(ok,'Atomic checkpoint replacement failed: %s',message);
end

