function result=runC1IndependentSeed20(root,out,options)
%RUNC1INDEPENDENTSEED20 Independent 20-physical-packet paired C1 check.
% Uses the existing packet builder and receiver; only the method list and
% output location are new. No frozen result is read or overwritten.
if nargin<1||isempty(root),root=pwd;end
if nargin<2||isempty(out),out=fullfile(root,'c1_final_evidence_round3','experiments','independent_seed_20261009');end
if nargin<3||isempty(options),options=struct();end
if ~isfield(options,'resume'),options.resume=false;end
checkpoint=fullfile(out,'independent_seed_checkpoint.mat');
entries=setdiff({dir(out).name},{'.','..'});
assert(options.resume||isempty(entries), ...
    'Refusing to overwrite a nonempty independent-seed output directory; use options.resume=true.');
if exist(out,'dir')~=7,mkdir(out);end
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);
cfg.experimentName="c1_independent_seed20_payload169";
cfg.masterSeed=2026100901;cfg.bootstrapSeed=2026100902;cfg.smokeSeed=2026100903;
cfg.SNRdBGrid=20;cfg.fdHz=200;cfg.rho=ofdm.uavDopplerToRho(cfg.fdHz,cfg.Tsym);
cfg.noiseVar=10^(-20/10);
cfg.scenarioCount=20;cfg.Ncodeword=1;cfg.Npayload=cfg.symbolsPerCodeword;cfg.fixedRadius=3;
cfg.methods=["BaseKalmanCausal_EP","FixedRadius3Causal_EP", ...
    "CovarianceAwareLocalDAKalmanCausal_EP","GramOnlyLocalDAKalmanCausal_EP", ...
    "ResidualOnlyLocalDAKalmanCausal_EP"];
cfg.outputDirectory=out;cfg.targetCodewordBler=.10;cfg.realizedSnrToleranceDb=.15;
schema=localSchema();
if options.resume
    assert(isfile(checkpoint),'Resume requested but checkpoint is missing.');s=load(checkpoint);
    assert(s.cfg.masterSeed==cfg.masterSeed&&isequal(s.cfg.methods,cfg.methods), ...
        'Checkpoint configuration mismatch.');
    T=s.T;
    % The packet phase used an older out-of-range bootstrap metadata value.
    % Correct only this metadata column before final statistical post-processing;
    % packet-level numerical fields are not recomputed or changed.
    T.bootstrapSeed(:)=cfg.bootstrapSeed;
    firstScenario=s.nextScenario;
    if string(s.status)=="complete",firstScenario=cfg.scenarioCount+1;end
else
    T=cell2table(cell(0,numel(schema)),'VariableNames',cellstr(schema));firstScenario=1;
end
for scenarioIndex=firstScenario:cfg.scenarioCount
    scenario=auditBuildPairedSnrScenario(cfg,scenarioIndex);
    packet=auditRealizePairedSnrScenario(cfg,scenario,20);
    online=struct('pilotObservation',packet.obs,'receivedData',packet.y, ...
        'validDataMask',packet.validReMask,'validReMask',packet.validReMask, ...
        'noiseVar',cfg.noiseVar,'rho',cfg.rho,'Npayload',packet.Npayload, ...
        'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
    scenarioRows=cell(numel(cfg.methods),1);
    for methodIndex=1:numel(cfg.methods)
        method=cfg.methods(methodIndex);tic
        estimate=c1RunSingleEstimatorAblation(cfg,online,method);
        Hhat=estimate.Hhat;
        receiver=auditMechanismOnlineReceive(cfg,online,Hhat,estimate.onlineEstimationRuntimeSeconds);
        metric=auditMechanismOfflineDetectionMetrics(cfg,receiver,Hhat,packet.H,packet.qam,packet.codedBits,packet.validReMask);
        h=scenario.hashes;
        scenarioRows{methodIndex}=table(string(cfg.experimentName),cfg.masterSeed,cfg.bootstrapSeed, ...
            cfg.SNRdBGrid,cfg.fdHz,scenarioIndex,scenario.scenarioSeed,method, ...
            h.H,h.txBits,h.qam,h.paddingBits,h.paddingSymbols,h.unitNoise,packet.sharedHashY, ...
            metric.csiNmse,metric.preLdpcBer,metric.softEvmRms,metric.softEvmRms^2, ...
            metric.codewordPassRate,metric.payloadGoodputMbps, ...
            estimate.onlineEstimationRuntimeSeconds+metric.offlineAuditRuntimeSeconds, ...
            estimate.audit.daUpdateCount,estimate.audit.candidateFeasibleCount, ...
            localMinEigen(estimate.audit),double(receiver.hasNaN),double(receiver.hasInf), ...
            toc,'VariableNames',cellstr(schema));
        fprintf('independent seed: packet=%d/%d method=%s NMSE=%.6g preBER=%.6g\n', ...
            scenarioIndex,cfg.scenarioCount,method,metric.csiNmse,metric.preLdpcBer);
    end
    T=[T;vertcat(scenarioRows{:})]; %#ok<AGROW>
    nextScenario=scenarioIndex+1;status="running";save(checkpoint,'cfg','T','nextScenario','status','-v7.3');
    fprintf('checkpoint saved: completed physical packets=%d/%d\n',scenarioIndex,cfg.scenarioCount);
end
assert(height(T)==cfg.scenarioCount*numel(cfg.methods));
localPairingGate(T,cfg);writetable(T,fullfile(out,'independent_seed_packet_results.csv'));
save(fullfile(out,'independent_seed_results.mat'),'cfg','T','-v7.3');
localWriteManifest(root,out,cfg);
P=localPairedStatistics(T,cfg);writetable(P,fullfile(out,'independent_seed_paired_statistics.csv'));
result=struct('status',"complete",'cfg',cfg,'packetTable',T,'pairedStatistics',P,'outputDirectory',out);
status="complete";nextScenario=cfg.scenarioCount+1;save(checkpoint,'cfg','T','nextScenario','status','-v7.3');
fprintf('independent seed complete: rows=%d packets=%d methods=%d\n',height(T),cfg.scenarioCount,numel(cfg.methods));
end

function names=localSchema()
names={"experimentName","masterSeed","bootstrapSeed","SNRdB","fdHz","packetIndex","scenarioSeed","method", ...
    "sharedHashH","sharedHashTxBits","sharedHashQam","sharedHashPaddingBits","sharedHashPaddingSymbols", ...
    "sharedHashUnitNoise","sharedHashY","csiNmse","preLdpcBer","softEvmRms","softEvmSquared", ...
    "codewordPassRate","goodputMbps","runtimeSeconds","daUpdateCount","candidateFeasibleCount", ...
    "minRlsEigenvalue","hasNaN","hasInf","wrapperSeconds"};
end

function v=localMinEigen(a)
if isfield(a,'minRlsEigenvalue')
    x=a.minRlsEigenvalue(isfinite(a.minRlsEigenvalue));
    if isempty(x)
        v=NaN;
    else
        v=min(x);
    end
else
    v=NaN;
end
end

function localPairingGate(T,cfg)
assert(all(isfinite(T.csiNmse))&&all(isfinite(T.preLdpcBer))&&all(isfinite(T.softEvmRms)));
assert(~any(T.hasNaN|T.hasInf));assert(all(abs(T.SNRdB-20)<eps));
for p=1:cfg.scenarioCount
    x=T(T.packetIndex==p,:);assert(height(x)==numel(cfg.methods));
    for n=["sharedHashH","sharedHashTxBits","sharedHashQam","sharedHashPaddingBits","sharedHashPaddingSymbols","sharedHashUnitNoise","sharedHashY"]
        assert(isscalar(unique(x.(n))),"Pairing mismatch in %s packet %d",n,p);
    end
end
end

function P=localPairedStatistics(T,cfg)
metrics=["csiNmse","preLdpcBer","softEvmRms"];reference=cfg.methods(1);
cells=cell((numel(cfg.methods)-1)*numel(metrics)*2,1);cursor=0;
for b=2:numel(cfg.methods)
    for mi=1:numel(metrics)
        metric=metrics(mi);a=localByPacket(T,reference,metric);y=localByPacket(T,cfg.methods(b),metric);
        ci=auditPairedBootstrapCi(y-a,cfg.bootstrapSeed+1000*b+mi,10000);cursor=cursor+1;
        cells{cursor}=table(reference,cfg.methods(b),metric,numel(a),mean(y-a),ci.ciLower95,ci.ciUpper95, ...
            cfg.masterSeed,ci.seed,ci.replicates,'VariableNames',{'referenceMethod','comparisonMethod','metric','packetCount','meanDelta','ciLower95','ciUpper95','masterSeed','bootstrapSeed','bootstrapReplicates'});
    end
end
% Proposed against both covariance ablations is the mechanism-specific comparison.
for b=[4 5]
    for mi=1:numel(metrics)
        metric=metrics(mi);a=localByPacket(T,cfg.methods(3),metric);y=localByPacket(T,cfg.methods(b),metric);
        ci=auditPairedBootstrapCi(y-a,cfg.bootstrapSeed+2000*b+mi,10000);cursor=cursor+1;
        cells{cursor}=table(cfg.methods(3),cfg.methods(b),metric,numel(a),mean(y-a),ci.ciLower95,ci.ciUpper95, ...
            cfg.masterSeed,ci.seed,ci.replicates,'VariableNames',{'referenceMethod','comparisonMethod','metric','packetCount','meanDelta','ciLower95','ciUpper95','masterSeed','bootstrapSeed','bootstrapReplicates'});
    end
end
P=vertcat(cells{1:cursor});
end

function x=localByPacket(T,method,metric)
metricName=char(metric);
part=sortrows(T(T.method==method,{'packetIndex',metricName}),'packetIndex');
x=part.(metricName);
end

function localWriteManifest(root,out,cfg)
paths={fullfile(root,'c1_final_evidence_round3','experiments','runC1IndependentSeed20.m'); ...
    fullfile(root,'c1_final_evidence_round3','experiments','ablation','c1RunSingleEstimatorAblation.m'); ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditMechanismOfflineDetectionMetrics.m'); ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditMechanismOnlineReceive.m'); ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditBuildPairedSnrScenario.m'); ...
    fullfile(root,'audit_three_layer_helpers','quality_aware_proposed','auditRealizePairedSnrScenario.m')};
f=fopen(fullfile(out,'independent_seed_manifest.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'experiment=%s\nmasterSeed=%d\nbootstrapSeed=%d\nSNRdB=%g\nfdHz=%g\npacketCount=%d\nNpayload=%d\nNcodeword=%d\nMATLAB=%s\n', ...
    cfg.experimentName,cfg.masterSeed,cfg.bootstrapSeed,cfg.SNRdBGrid,cfg.fdHz,cfg.scenarioCount,cfg.Npayload,cfg.Ncodeword,version);
for i=1:numel(paths),fprintf(f,'source=%s\nsha256=%s\n',paths{i},auditFileSha256(paths{i}));end
fprintf(f,'methods=%s\nnoSeedFiltering=true\nresamplingUnit=physical_packet\n',strjoin(cfg.methods,','));
end
