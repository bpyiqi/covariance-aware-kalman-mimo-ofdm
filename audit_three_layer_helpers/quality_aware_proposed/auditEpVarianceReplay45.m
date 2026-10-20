function result=auditEpVarianceReplay45(root,options)
%AUDITEPVARIANCEREPLAY45 Deterministic dev12 packet replay with EP diagnostics.
arguments,root (1,:) char,options.run (1,1) logical=false,end
cfg=auditEpVarianceReplay45Config(root);source=auditEpVarianceReplay45Preflight(cfg);
if ~options.run
    assert(exist(cfg.outputDirectory,'dir')~=7,'Dry-run must not create replay output.');
    result=struct('dryRun',true,'expectedReceiverRuns',45,'verifiedSourceChunks',source.chunkCount,'receiverRuns',0,'newPhysicalSeeds',0);
    fprintf('EP variance replay45 dry-run PASS: expectedReceiverRuns=45, dev12 chunks/hashes=12, receiverRuns=0, physicalSeeds=0.\n');return;
end
auditRefuseNonemptyOutput(cfg.outputDirectory);if exist(cfg.outputDirectory,'dir')~=7,mkdir(cfg.outputDirectory);end
sourceCfg=source.sourceCfg;covariance=load(sourceCfg.covariancePath,'covariance');allRows=cell(numel(cfg.scenarioIndices),1);allExtreme=cell(numel(cfg.scenarioIndices),1);completed=zeros(numel(cfg.scenarioIndices),1);
for scenarioCursor=1:numel(cfg.scenarioIndices)
    scenarioIndex=cfg.scenarioIndices(scenarioCursor);
    [scenarioRows,scenarioRecords,extremeRows]=localScenario(cfg,source,sourceCfg,covariance.covariance,scenarioIndex);
    chunkPath=fullfile(cfg.outputDirectory,sprintf('ep_variance_scenario_%02d.mat',scenarioIndex));save(chunkPath,'scenarioRecords','scenarioRows','extremeRows','scenarioIndex','-v7.3');
    allRows{scenarioCursor}=scenarioRows;
    if isempty(extremeRows)||all(cellfun(@(x)width(x)==0,extremeRows)),allExtreme{scenarioCursor}=table();else,allExtreme{scenarioCursor}=vertcat(extremeRows{cellfun(@(x)width(x)>0,extremeRows)});end
    completed(scenarioCursor)=scenarioIndex;
    checkpoint=fullfile(cfg.outputDirectory,'ep_variance_replay_checkpoint.mat');save(checkpoint,'cfg','source','completed','allRows','allExtreme','-v7.3');
end
rows=vertcat(allRows{:});validExtreme=allExtreme(cellfun(@(x)width(x)>0,allExtreme));if isempty(validExtreme),extreme=table();else,extreme=vertcat(validExtreme{:});end;localArtifacts(cfg,source,rows,extreme,completed);
result=struct('dryRun',false,'receiverRuns',45,'newPhysicalSeeds',0,'outputDirectory',string(cfg.outputDirectory));
end
function [rows,records,extremeRows]=localScenario(cfg,source,base,covariance,scenarioIndex)
scenario=auditBuildPairedSnrScenario(base,scenarioIndex);frozen=load(source.chunkPaths(scenarioIndex),'chunk');assert(localSameHashes(scenario.hashes,frozen.chunk.scenarioHashes));
rows=cell(numel(cfg.SNRdBGrid)*numel(cfg.methods),1);records=cell(size(rows));extremeRows=cell(numel(rows),1);cursor=0;extremeCursor=0;
for snr=cfg.SNRdBGrid
    point=base;point.SNRdB=snr;point.noiseVar=10^(-snr/10);packet=auditRealizePairedSnrScenario(point,scenario,snr);
    online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'validDataMask',packet.validReMask,'validReMask',packet.validReMask,'noiseVar',point.noiseVar,'rho',point.rho,'Npayload',packet.Npayload,'nCodeword',packet.nCodeword,'usefulBitMask',packet.usefulBitMask);
    for method=cfg.methods
        if method=="OJCD_LMMSE_EP_Adapted"
            oj=auditCovarianceAwareOjcdReceive(point,packet,covariance,captureEpDiagnostics=true);Hhat=oj.Hhat;receiver=oj.receiver;
        elseif method=="PerfectCSI_EP"
            Hhat=packet.H;receiver=auditMechanismOnlineReceive(point,online,Hhat,0,captureEpDiagnostics=true);
        else
            estimate=auditMechanismRunSingleEstimator(point,online,method);Hhat=estimate.Hhat;receiver=auditMechanismOnlineReceive(point,online,Hhat,estimate.onlineEstimationRuntimeSeconds,captureEpDiagnostics=true);
        end
        expected=localExpected(frozen.chunk,snr,method);raw=double(receiver.llr(scenario.usefulBitMask));rawHash=localHash(single(raw));assert(rawHash==localHash(expected.rawUsefulLlr)&&packet.sharedHashY==localExpectedY(source.receiverRows,scenarioIndex,snr,method));
        [record,summary,extreme]=localOfflineRecord(method,scenarioIndex,snr,receiver,Hhat,packet,scenario,point);cursor=cursor+1;records{cursor}=record;rows{cursor}=summary;
        if ~isempty(extreme),extremeCursor=extremeCursor+1;extremeRows{extremeCursor}=extreme;end
    end
end
rows=vertcat(rows{1:cursor});records=records(1:cursor);if extremeCursor==0,extremeRows={table()};else,extremeRows=extremeRows(1:extremeCursor);end
end
function expected=localExpected(chunk,snr,method)
for i=1:numel(chunk.records),x=chunk.records{i};if x.targetSnrDb==snr&&x.method==method,expected=x;return;end,end
error('Frozen receiver record is missing.');
end
function value=localExpectedY(T,scenario,snr,method)
x=T(T.scenarioIndex==scenario&T.targetSnrDb==snr&T.method==method,:);assert(height(x)==1);value=x.sharedHashY;
end
function [record,summary,extreme]=localOfflineRecord(method,scenarioIndex,snr,receiver,Hhat,packet,scenario,point)
N=scenario.Npayload;layers="single";if method=="OJCD_LMMSE_EP_Adapted",layers=["jcd1","jcd2"];end
parts=cell(numel(layers),1);summaryParts=cell(numel(layers),1);extreme=cell(numel(layers),1);ec=0;
for li=1:numel(layers)
    rows=cell(nnz(packet.validReMask)*2,1);c=0;
    for n=1:N
        for d=find(packet.validReMask(:,n)).'
        diag=localDiag(receiver,d,n,layers(li));xtrue=squeeze(scenario.qam(:,d,n));y=squeeze(packet.y(d,n,:));H=squeeze(Hhat(point.data(d),n,:,:));residual=norm(y-H*xtrue)^2/point.noiseVar;
        trueBits=logical(qamdemod(xtrue,16,'UnitAveragePower',true,'OutputType','bit')).';
        for stream=1:2,c=c+1;ve=diag.extrinsicVariance(stream);vp=diag.posteriorVariance(stream);xe=diag.extrinsicMean(stream);xp=diag.posteriorMean(stream);llr=diag.bitLlr(stream,:).';bits=trueBits(:,stream);wrong=(llr<0)~=bits;
            rows{c}=table(method,scenarioIndex,snr,layers(li),n,d,stream,diag.sigmaDiag(stream),diag.cavityDenominator(stream),ve,xe,vp,xp,diag.varianceUsedForLlr(stream),diag.lambdaBeforeUpdate(stream),diag.lambdaCandidate(stream),diag.gramRcond,diag.precisionFloorHits,diag.varianceFloorHits,diag.negativePrecisionCandidates,diag.nonfiniteCandidates,diag.rollbackCount,diag.minimumExtrinsicVariance,diag.minimumPosteriorVariance,diag.minimumAbsCavityDenominator,residual,abs(xe-xtrue(stream))^2/max(ve,eps),abs(xp-xtrue(stream))^2/max(vp,eps),mean(wrong),sum(wrong&abs(llr)>=10),mean(abs(llr)),localMean(abs(llr(wrong))),localMax(abs(llr(wrong))), ...
            'VariableNames',{'method','scenarioIndex','targetSnrDb','layer','ofdmSymbol','dataIndex','stream','sigmaDiag','cavityDenominator','extrinsicVariance','extrinsicMean','posteriorVariance','posteriorMean','varianceUsedForLlr','lambdaBeforeUpdate','lambdaCandidate','gramRcond','precisionFloorHits','varianceFloorHits','negativePrecisionCandidates','nonfiniteCandidates','rollbackCount','minimumVe','minimumVp','minimumAbsDenominator','residualPowerOverNoise','xeErrorOverVe','xpErrorOverVp','bitErrorRate','highConfidenceWrongBitCount10','meanAbsLlr','wrongBitMeanAbsLlr','wrongBitMaxAbsLlr'});
        end
        end
    end
    parts{li}=vertcat(rows{1:c});summaryParts{li}=localSummary(parts{li});e=parts{li}(parts{li}.highConfidenceWrongBitCount10>0|parts{li}.rollbackCount>0|parts{li}.varianceFloorHits>0,:);if ~isempty(e),ec=ec+1;extreme{ec}=e;end
end
record=struct('method',method,'scenarioIndex',scenarioIndex,'targetSnrDb',snr,'layers',{layers},'perReStream',{parts});summary=vertcat(summaryParts{:});if ec==0,extreme=table();else,extreme=vertcat(extreme{:});end
end
function diag=localDiag(receiver,d,n,layer)
if layer=="single",diag=receiver.epDiagnostics{d,n};elseif layer=="jcd1",diag=receiver.jcd1EpDiagnostics{d,n};else,diag=receiver.jcd2EpDiagnostics{d,n};end
end
function T=localSummary(x)
T=table(x.method(1),x.scenarioIndex(1),x.targetSnrDb(1),x.layer(1),height(x),mean(x.sigmaDiag),mean(x.extrinsicVariance),mean(x.posteriorVariance),mean(x.residualPowerOverNoise),mean(x.xeErrorOverVe),mean(x.xpErrorOverVp),mean(x.bitErrorRate),sum(x.highConfidenceWrongBitCount10),sum(x.precisionFloorHits),sum(x.varianceFloorHits),sum(x.negativePrecisionCandidates),sum(x.nonfiniteCandidates),sum(x.rollbackCount),min(x.minimumVe),min(x.minimumVp),min(x.minimumAbsDenominator), ...
'VariableNames',{'method','scenarioIndex','targetSnrDb','layer','reStreamCount','meanSigmaDiag','meanVe','meanVp','meanResidualPowerOverNoise','meanXeErrorOverVe','meanXpErrorOverVp','meanBitErrorRate','highConfidenceWrongBitCount10','precisionFloorHits','varianceFloorHits','negativePrecisionCandidates','nonfiniteCandidates','rollbackCount','minimumVe','minimumVp','minimumAbsDenominator'});
end
function localArtifacts(cfg,source,rows,extreme,completed)
if width(extreme)==0,extreme=table(strings(0,1),'VariableNames',{'noExtremeEvents'});end
writetable(rows,fullfile(cfg.outputDirectory,'ep_variance_replay_method_snr.csv'));writetable(rows(:,{'method','targetSnrDb','layer','meanBitErrorRate','highConfidenceWrongBitCount10'}),fullfile(cfg.outputDirectory,'ep_variance_replay_correct_error.csv'));writetable(rows(:,{'method','targetSnrDb','layer','precisionFloorHits','varianceFloorHits','negativePrecisionCandidates','nonfiniteCandidates','rollbackCount','minimumVe','minimumVp','minimumAbsDenominator'}),fullfile(cfg.outputDirectory,'ep_variance_replay_floor_rollback.csv'));writetable(rows(rows.method=="OJCD_LMMSE_EP_Adapted",:),fullfile(cfg.outputDirectory,'ep_variance_replay_ojcd_layers.csv'));writetable(extreme,fullfile(cfg.outputDirectory,'ep_variance_replay_extreme_events.csv'));save(fullfile(cfg.outputDirectory,'ep_variance_replay_results.mat'),'cfg','source','rows','extreme','completed','-v7.3');
f=fopen(fullfile(cfg.outputDirectory,'ep_variance_replay_report.txt'),'w','n','UTF-8');assert(f>=0);fprintf(f,'Deterministic dev12 replay with diagnostic-only EP capture. receiverRuns=%d; newPhysicalSeeds=0; truth is used only after receiver return. Per-RE data are stored in ep_variance_scenario_*.mat.\n',height(rows));fclose(f);fclose(fopen(fullfile(cfg.outputDirectory,'COMPLETE'),'w'));
end
function tf=localSameHashes(a,b),tf=isequaln(a,b);end
function value=localHash(data),v=double(data(:));w=mod((1:numel(v))',104729)+1;value=sum(real(v).*w)+sqrt(2)*sum(imag(v).*w)+sum(abs(v).^2)/max(numel(v),1);end
function value=localMean(x),if isempty(x),value=0;else,value=mean(x);end,end
function value=localMax(x),if isempty(x),value=0;else,value=max(x);end,end
