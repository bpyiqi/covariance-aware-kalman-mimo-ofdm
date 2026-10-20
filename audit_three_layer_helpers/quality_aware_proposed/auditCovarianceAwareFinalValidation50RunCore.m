function result=auditCovarianceAwareFinalValidation50RunCore(cfg,out,options)
%AUDITCOVARIANCEAWAREFINALVALIDATION50RUNCORE Paired executor with checkpoint.
arguments,cfg struct,out (1,:) char,options.resume (1,1) logical=false,options.stopAfterPackets (1,1) double=inf,options.testMode (1,1) logical=false,end
schema=auditCovarianceAwareFinalValidation50Schema();methods=cfg.methods;assert(numel(methods)==6);checkpointPath=fullfile(out,schema.files.checkpoint);
[packetTable,completedKeys]=localStart(out,checkpointPath,cfg,schema,options.resume);physicalDone=height(completedKeys);
for ci=1:numel(cfg.Ncodeword)
    conditionSeed=cfg.validationSeed+100000*cfg.Ncodeword(ci);
    for pi=1:cfg.packetCountPerCondition
        payload=cfg.symbolsPerCodeword*cfg.Ncodeword(ci);if localCompleted(completedKeys,payload,pi),continue;end
        packetSeed=conditionSeed+pi;rng(packetSeed,'twister');packet=auditQualityAwareMiniPacket(cfg,cfg.Ncodeword(ci));packetRows=localRunPacket(cfg,packet,pi,conditionSeed,packetSeed);
        packetTable=[packetTable;packetRows];completedKeys=[completedKeys;table(payload,pi,'VariableNames',{'payloadSymbols','packetIndex'})];physicalDone=physicalDone+1; %#ok<AGROW>
        localSaveCheckpoint(checkpointPath,cfg,schema,packetTable,completedKeys,"running",payload,pi);
        fprintf('validation50 checkpoint: payloadSymbols=%d packetIndex=%d rows=%d\n',payload,pi,height(packetTable));
        if physicalDone>=options.stopAfterPackets,result=struct('status',"interrupted_for_test",'packetTable',packetTable,'outputDirectory',out);return;end
    end
end
auditCovarianceAwareFinalizeArtifacts(cfg,out,packetTable,options.testMode);
localSaveCheckpoint(checkpointPath,cfg,schema,packetTable,completedKeys,"complete",completedKeys.payloadSymbols(end),completedKeys.packetIndex(end));
file=fopen(fullfile(out,schema.files.complete),'w');assert(file>=0);fprintf(file,'complete\n');fclose(file);
result=struct('status',"complete",'packetTable',packetTable,'randomPhysicalPacketCount',height(completedKeys),'outputDirectory',out);
end

function rows=localRunPacket(cfg,p,pi,conditionSeed,packetSeed)
online=struct('pilotObservation',p.obs,'receivedData',p.y,'validDataMask',p.validReMask,'validReMask',p.validReMask,'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',p.Npayload,'nCodeword',p.nCodeword,'usefulBitMask',p.usefulBitMask);
legacy=auditQualityAwareLegacyCausalEstimates(cfg,p,3);covariance=localCovariance(cfg);rows=cell(6,1);
for mi=1:6
    method=cfg.methods(mi);audit=localEmptyAudit();authorizedTruth=0;
    switch mi
        case 1,est=auditMechanismRunSingleEstimator(cfg,online,"BaseKalmanCausal_EP");[receiver,Hhat,audit,solver]=localStandard(cfg,online,est);
        case 2,est=auditMechanismRunSingleEstimator(cfg,online,"FixedRadius3Causal_EP");[receiver,Hhat,audit,solver]=localStandard(cfg,online,est);
        case 3,est=auditMechanismRunSingleEstimator(cfg,online,"CovarianceAwareLocalDAKalmanCausal_EP");[receiver,Hhat,audit,solver]=localStandard(cfg,online,est);
        case 4,oj=auditCovarianceAwareOjcdReceive(cfg,p,covariance);receiver=oj.receiver;Hhat=oj.Hhat;solver=oj.solverFailureCount;
        case 5,Hhat=legacy.Horacle;receiver=auditMechanismOnlineReceive(cfg,online,Hhat,legacy.oracleAudit.runtimeSeconds);solver=legacy.oracleAudit.solverFailureCount;authorizedTruth=1;
        case 6,Hhat=p.H;receiver=auditMechanismOnlineReceive(cfg,online,Hhat,0);solver=0;authorizedTruth=1;
    end
    metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,Hhat,p.H,p.qam,p.codedBits,p.validReMask);metric.onlineRuntimeSeconds=receiver.onlineRuntimeSeconds;rows{mi}=localRow(cfg,metric,audit,p,method,pi,conditionSeed,packetSeed,mi,solver,authorizedTruth);
end
rows=vertcat(rows{:});
end
function [receiver,Hhat,audit,solver]=localStandard(cfg,online,est),Hhat=est.Hhat;audit=est.audit;solver=audit.solverFailureCount;receiver=auditMechanismOnlineReceive(cfg,online,Hhat,est.onlineEstimationRuntimeSeconds);end
function T=localRow(cfg,m,a,p,method,pi,cs,ps,order,solver,authorizedTruth)
schema=auditCovarianceAwareFinalValidation50Schema();isDa=ismember(method,["FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"]);count=@(v)double(v);continuous=@(v)double(v);
values={cfg.experimentName,cfg.validationSeed,cfg.bootstrapSeed,p.Npayload,p.nCodeword,pi,method,cs,ps,order,p.hashes.channelHash,p.hashes.receivedSignalHash,p.hashes.transmitBitsHash,p.hashes.paddingBitsHash,p.hashes.paddingSymbolsHash,nnz(~p.validReMask),m.csiNmse,m.worstStreamCsiNmse,m.p95ReNormalizedError,m.p99ReNormalizedError,m.deepFadeCsiNmse,m.preLdpcBer,NaN,double(m.codewordPassRate==1),m.codewordPassRate,m.payloadGoodputMbps,m.softEvmRms,m.softEvmRms^2,m.onlineRuntimeSeconds+m.offlineAuditRuntimeSeconds,0,0,authorizedTruth,solver,0,0,count(localOrZero(a,'pilotUpdateCount')),count(localOrZero(a,'daUpdateCount')),count(localApplicable(a,'candidateFeasibleCount',isDa)),count(localApplicable(a,'daUpdateCount',isDa)),count(localApplicable(a,'noCandidateCount',isDa)),continuous(localApplicable(a,'rdaTraceMean',isDa)),continuous(localApplicable(a,'rdaTraceMedian',isDa)),continuous(localApplicable(a,'minRlsEigenvalueMin',isDa)),continuous(localApplicable(a,'rlsConditionNumberMax',isDa)),count(localApplicable(a,'daUpdateCount',isDa))};
T=cell2table(values,'VariableNames',cellstr(schema.packetLevel));
end
function v=localApplicable(a,name,yes),if ~yes,v=0;if any(contains(name,{'rdaTrace','Rls','Condition'})),v=NaN;end;return;end;if strcmp(name,'rdaTraceMean'),v=localStat(a.rdaTrace,'mean');elseif strcmp(name,'rdaTraceMedian'),v=localStat(a.rdaTrace,'median');elseif strcmp(name,'minRlsEigenvalueMin'),v=localStat(a.minRlsEigenvalue,'min');elseif strcmp(name,'rlsConditionNumberMax'),v=localStat(a.rlsConditionNumber,'max');else,v=localOrZero(a,name);end,end
function v=localOrZero(a,name),if isfield(a,name),v=a.(name);else,v=0;end,end
function a=localEmptyAudit(),a=struct('candidateFeasibleCount',0,'daUpdateCount',0,'noCandidateCount',0,'pilotUpdateCount',0,'rdaTrace',NaN,'solverFailureCount',0);end
function c=localCovariance(cfg),s=load(cfg.covariancePath,'covariance');c=s.covariance;end
function v=localStat(x,kind),x=x(isfinite(x));if isempty(x),v=NaN;else,v=feval(kind,x);end,end
function yes=localCompleted(keys,payload,index),yes=~isempty(keys)&&any(keys.payloadSymbols==payload&keys.packetIndex==index);end
function [rows,keys]=localStart(out,path,cfg,schema,resume)
entries=dir(out);nonempty=exist(out,'dir')&&any(~ismember({entries.name},{'.','..'}));
if nonempty
    assert(resume,'Refusing to overwrite nonempty output directory: %s',out);assert(exist(path,'file')==2,'Resume requested but checkpoint is missing: %s',path);s=load(path);localCheckCheckpoint(s,cfg,schema);rows=s.packetTable;keys=s.completedKeys;
else
    assert(~resume,'Resume requested but no checkpoint directory exists: %s',out);if ~exist(out,'dir'),mkdir(out);end;rows=cell2table(cell(0,numel(schema.packetLevel)),'VariableNames',cellstr(schema.packetLevel));keys=table([],[],'VariableNames',{'payloadSymbols','packetIndex'});
end
end
function localCheckCheckpoint(s,cfg,schema),assert(s.validationSeed==cfg.validationSeed&&s.bootstrapSeed==cfg.bootstrapSeed&&isequal(s.methods,cfg.methods)&&isequal(s.Npayload,cfg.Npayload)&&s.packetCountPerCondition==cfg.packetCountPerCondition&&string(s.schemaVersion)==schema.version&&s.cfg.fixedRadius==cfg.fixedRadius&&isequal(s.cfg.radii,cfg.radii)&&s.cfg.llrThreshold==cfg.llrThreshold&&s.cfg.minEffectiveSamples==cfg.minEffectiveSamples&&s.cfg.gramRcondThreshold==cfg.gramRcondThreshold,'Checkpoint configuration mismatch.');assert(string(s.status)~="complete",'Checkpoint already represents a complete run.');rng(s.rngState);end
function localSaveCheckpoint(path,cfg,schema,packetTable,completedKeys,status,payload,index)
path=char(path);tmp=[path '.tmp'];methods=cfg.methods;validationSeed=cfg.validationSeed;bootstrapSeed=cfg.bootstrapSeed;Npayload=cfg.Npayload;packetCountPerCondition=cfg.packetCountPerCondition;schemaVersion=schema.version;rngState=rng;checkpointVersion="1.0";createdAt=string(datetime('now'));lastCompletedPayload=payload;lastCompletedPacketIndex=index;save(tmp,'cfg','methods','validationSeed','bootstrapSeed','Npayload','packetCountPerCondition','schemaVersion','packetTable','completedKeys','rngState','checkpointVersion','createdAt','lastCompletedPayload','lastCompletedPacketIndex','status','-v7.3');[ok,msg]=movefile(tmp,path,'f');assert(ok,'Atomic checkpoint replacement failed: %s',msg);
end
