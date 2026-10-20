function result=auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,out,options)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20RUNCORE Scenario-atomic CRN executor.
arguments,cfg struct,out (1,:) char,options.resume (1,1) logical=false, ...
    options.stopAfterScenarios (1,1) double=inf,options.testMode (1,1) logical=false,end
schema=auditCovarianceAwareSnrPairedLocalization20Schema();checkpoint=fullfile(out,schema.files.checkpoint);
[T,completed]=localStart(out,checkpoint,cfg,schema,options.resume);done=numel(completed);covariance=localCovariance(cfg);
for scenarioIndex=1:cfg.scenarioCount
    if ismember(scenarioIndex,completed),continue;end
    scenario=auditBuildPairedSnrScenario(cfg,scenarioIndex);scenarioRows=cell(numel(cfg.SNRdBGrid),1);
    for si=1:numel(cfg.SNRdBGrid)
        snrDb=cfg.SNRdBGrid(si);pointCfg=cfg;pointCfg.SNRdB=snrDb;pointCfg.noiseVar=10^(-snrDb/10);
        packet=auditRealizePairedSnrScenario(pointCfg,scenario,snrDb);
        scenarioRows{si}=localRunSnr(pointCfg,scenario,packet,covariance);
    end
    scenarioRows=vertcat(scenarioRows{:});localScenarioGate(scenarioRows,cfg);
    T=[T;scenarioRows];completed=[completed;scenarioIndex];done=done+1; %#ok<AGROW>
    localSave(checkpoint,cfg,schema,T,completed,"running",scenarioIndex);
    fprintf('paired localization checkpoint: scenario=%d rows=%d\n',scenarioIndex,height(T));
    if done>=options.stopAfterScenarios,result=struct('status',"interrupted_for_test",'packetTable',T,'outputDirectory',out);return;end
end
artifacts=auditCovarianceAwareSnrPairedLocalization20Finalize(cfg,out,T,options.testMode);
localSave(checkpoint,cfg,schema,T,completed,"complete",completed(end));
f=fopen(fullfile(out,schema.files.complete),'w');assert(f>=0);fprintf(f,'complete\n');fclose(f);
result=struct('status',"complete",'packetTable',T,'artifacts',artifacts,'randomScenarioCount',numel(completed),'outputDirectory',out);
end

function rows=localRunSnr(cfg,scenario,p,covariance)
online=struct('pilotObservation',p.obs,'receivedData',p.y,'validDataMask',p.validReMask,'validReMask',p.validReMask, ...
    'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',p.Npayload,'nCodeword',p.nCodeword,'usefulBitMask',p.usefulBitMask);
rows=cell(numel(cfg.methods),1);
for mi=1:numel(cfg.methods)
    method=cfg.methods(mi);audit=localEmptyAudit();authorized=0;solver=0;
    switch method
        case {"BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"}
            estimate=auditMechanismRunSingleEstimator(cfg,online,method);Hhat=estimate.Hhat;audit=estimate.audit;
            receiver=auditMechanismOnlineReceive(cfg,online,Hhat,estimate.onlineEstimationRuntimeSeconds);solver=audit.solverFailureCount;
        case "OJCD_LMMSE_EP_Adapted"
            oj=auditCovarianceAwareOjcdReceive(cfg,p,covariance);Hhat=oj.Hhat;receiver=oj.receiver;solver=oj.solverFailureCount;
        case "PerfectCSI_EP"
            Hhat=p.H;receiver=auditMechanismOnlineReceive(cfg,online,Hhat,0);authorized=1;
        otherwise,error('Unknown frozen method %s.',method);
    end
    metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,Hhat,p.H,p.qam,p.codedBits,p.validReMask);
    metric.onlineRuntimeSeconds=receiver.onlineRuntimeSeconds;
    rows{mi}=localRow(cfg,scenario,p,method,metric,audit,solver,authorized,receiver);
end
rows=vertcat(rows{:});
end

function T=localRow(cfg,s,p,method,m,a,solver,authorized,receiver)
schema=auditCovarianceAwareSnrPairedLocalization20Schema();isDa=ismember(method,["FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP"]);
decoded=m.totalCodewordCount;errors=decoded-m.passedCodewordCount;h=s.hashes;
values={cfg.experimentName,cfg.masterSeed,cfg.bootstrapSeed,p.targetSnrDb,cfg.fdHz,p.Npayload,p.nCodeword, ...
s.scenarioIndex,s.scenarioSeed,method,h.H,h.txBits,h.qam,h.paddingBits,h.paddingSymbols,h.unitNoise,p.sharedHashY, ...
nnz(~p.validReMask),p.cleanSignalPower,p.realizedNoisePower,p.realizedSnrDb,m.csiNmse,m.worstStreamCsiNmse, ...
m.p95ReNormalizedError,m.p99ReNormalizedError,m.deepFadeCsiNmse,m.preLdpcBer,NaN,double(m.codewordPassRate==1), ...
m.codewordPassRate,errors,decoded,m.payloadGoodputMbps,m.softEvmRms,m.softEvmRms^2, ...
m.onlineRuntimeSeconds+m.offlineAuditRuntimeSeconds,0,0,authorized,solver,0,0, ...
localApplicable(a,'candidateFeasibleCount',isDa),localApplicable(a,'daUpdateCount',isDa), ...
localApplicable(a,'noCandidateCount',isDa),localStat(a,'rdaTrace','mean',isDa),localStat(a,'rdaTrace','median',isDa), ...
localStat(a,'minRlsEigenvalue','min',isDa),localStat(a,'rlsConditionNumber','max',isDa), ...
localApplicable(a,'daUpdateCount',isDa),localApplicable(a,'daUpdateCount',isDa),0,0,0,0,0,0,0, ...
double(method~="PerfectCSI_EP"),double(isDa),double(receiver.hasNaN),double(receiver.hasInf)};
T=cell2table(values,'VariableNames',cellstr(schema.packetLevel));
end
function v=localApplicable(a,name,yes),if ~yes,v=0;elseif isfield(a,name),v=double(a.(name));else,v=0;end,end
function v=localStat(a,name,kind,yes),if ~yes||~isfield(a,name),v=NaN;return;end;x=a.(name);x=x(isfinite(x));if isempty(x),v=NaN;else,v=feval(kind,x);end,end
function a=localEmptyAudit(),a=struct('candidateFeasibleCount',0,'daUpdateCount',0,'noCandidateCount',0,'rdaTrace',NaN,'minRlsEigenvalue',NaN,'rlsConditionNumber',NaN,'solverFailureCount',0);end
function c=localCovariance(cfg),s=load(cfg.covariancePath,'covariance');c=s.covariance;end

function localScenarioGate(T,cfg)
assert(height(T)==numel(cfg.SNRdBGrid)*numel(cfg.methods));scenarioFields={'scenarioHashH','scenarioHashTxBits','scenarioHashQam','scenarioHashPaddingBits','scenarioHashPaddingSymbols','scenarioHashUnitNoise'};
for i=1:numel(scenarioFields),assert(isscalar(unique(T.(scenarioFields{i}))),'Cross-SNR scenario hash mismatch: %s.',scenarioFields{i});end
assert(numel(unique(T.sharedHashY))==numel(cfg.SNRdBGrid),'Received grids must differ across SNR.');
for snr=cfg.SNRdBGrid
    x=T(T.targetSnrDb==snr,:);assert(height(x)==numel(cfg.methods)&&isscalar(unique(x.sharedHashY)));
    for i=1:numel(scenarioFields),assert(isscalar(unique(x.(scenarioFields{i}))));end
end
assert(max(abs(T.realizedSnrDb-T.targetSnrDb))<=cfg.realizedSnrToleranceDb,'Realized SNR tolerance failed.');
assert(~any(T.hasNaN)&~any(T.hasInf)&all(T.solverFailureCount==0)&all(T.paddingDaUseCount==0));
assert(all(T.sameSymbolFeedbackCount==0)&all(T.futureSymbolReadCount==0)&all(T.legacySecondPassUseCount==0));
assert(all(T.withinSymbolDaFeedbackEvents==0)&all(T.stateRestartsAfterSymbol1==0)&all(T.crossSubcarrierStatePropagationEvents==0));
assert(all(T.repeatedPilotUseCount==0)&all(T.rejectedTargetsWithDaUpdate==0)&all(T.paddingTargetsWithDaUpdate==0));
assert(all(T.maxPilotUpdatesPerTarget<=1)&all(T.maxDaUpdatesPerTarget<=1));
ordinary=T.method~="PerfectCSI_EP";assert(all(T.testTruthOnlineUseCount(ordinary)==0));
end

function [T,completed]=localStart(out,path,cfg,schema,resume)
nonempty=false;if exist(out,'dir')==7,e=dir(out);nonempty=any(~ismember({e.name},{'.','..'}));end
if nonempty
    assert(resume,'Refusing to overwrite nonempty output directory: %s',out);assert(isfile(path),'Resume checkpoint missing.');
    s=load(path);localCheck(s,cfg,schema);T=s.packetTable;completed=s.completedScenarios;
else
    assert(~resume,'Resume requested without checkpoint.');if exist(out,'dir')~=7,mkdir(out);end
    T=cell2table(cell(0,numel(schema.packetLevel)),'VariableNames',cellstr(schema.packetLevel));completed=zeros(0,1);
end
end
function localCheck(s,cfg,schema)
assert(s.masterSeed==cfg.masterSeed&&s.bootstrapSeed==cfg.bootstrapSeed&&isequal(s.methods,cfg.methods)&& ...
isequal(s.SNRdBGrid,cfg.SNRdBGrid)&&s.scenarioCount==cfg.scenarioCount&&s.Npayload==cfg.Npayload&&string(s.schemaVersion)==schema.version,'Checkpoint configuration mismatch.');
assert(string(s.status)~="complete",'Checkpoint is already complete.');rng(s.rngState);
end
function localSave(path,cfg,schema,packetTable,completedScenarios,status,lastScenario)
tmp=[char(path) '.tmp'];masterSeed=cfg.masterSeed;bootstrapSeed=cfg.bootstrapSeed;methods=cfg.methods;SNRdBGrid=cfg.SNRdBGrid;
scenarioCount=cfg.scenarioCount;Npayload=cfg.Npayload;schemaVersion=schema.version;rngState=rng;scenarioSeeds=arrayfun(@(i)auditPairedSnrScenarioSeed(cfg.masterSeed,i),(1:cfg.scenarioCount).');
save(tmp,'cfg','masterSeed','bootstrapSeed','methods','SNRdBGrid','scenarioCount','Npayload','schemaVersion','packetTable','completedScenarios','scenarioSeeds','status','rngState','lastScenario','-v7.3');
[ok,msg]=movefile(tmp,path,'f');assert(ok,'Atomic checkpoint replacement failed: %s',msg);
end

