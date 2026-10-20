function result = auditQualityAwareProposedMini(root,varargin)
%AUDITQUALITYAWAREPROPOSEDMINI Manual nine-method paired random Mini.
parser=inputParser;parser.addParameter('dryRun',false,@(x)islogical(x)&&isscalar(x));
parser.addParameter('outputDirectory','',@(x)ischar(x)||(isstring(x)&&isscalar(x)));parser.parse(varargin{:});options=parser.Results;
cfg=auditQualityAwareDefaultConfig(root);if strlength(string(options.outputDirectory))==0,outputDirectory=cfg.miniOutput;else,outputDirectory=char(options.outputDirectory);end
preflight=auditQualityAwareMiniPreflight(root,cfg,outputDirectory);schema=auditQualityAwareMiniSchema();methods=cfg.miniMethods;
stateContainers=cell(numel(methods),1);for i=1:numel(methods),stateContainers{i}=struct('method',methods(i),'stateOwnerId',i);end
assert(numel(unique(cellfun(@(s)s.stateOwnerId,stateContainers)))==numel(methods),'Method state containers are not independent.');
if options.dryRun
    if ~exist(outputDirectory,'dir'),mkdir(outputDirectory);end
    tables=localDryTables(schema);reportPath=fullfile(outputDirectory,'quality_aware_mini_dry_run_report.txt');
    file=fopen(reportPath,'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));
    fprintf(file,'dryRun=1\nrandomPhysicalPacketCount=0\nmethodCount=%d\nmethods=%s\nseed=%d\nNpayload=%s\nallSchemasPresent=%d\noutputCollisionFree=%d\n',numel(methods),strjoin(methods,','),cfg.miniMasterSeed,mat2str(cfg.Npayload),localSchemaPass(tables,schema),preflight.outputCollisionFree);
    result=struct('dryRun',true,'randomPhysicalPacketCount',0,'cfg',cfg,'methods',methods, ...
        'schema',schema,'tables',tables,'preflight',preflight,'outputDirectory',outputDirectory, ...
        'stateContainers',{stateContainers});
    return;
end
if ~exist(outputDirectory,'dir'),mkdir(outputDirectory);end
loaded=load(cfg.covariancePath,'covariance');covariance=loaded.covariance;rng(cfg.miniMasterSeed,'twister');
physicalPacketCount=numel(cfg.Ncodeword)*cfg.miniPacketCountPerCondition;methodCount=numel(methods);
packetRows=cell(physicalPacketCount*methodCount,1);hashRows=cell(physicalPacketCount*methodCount,1);mechanismRows=cell(physicalPacketCount*3,1);packetCursor=0;methodCursor=0;mechanismCursor=0;wall=tic;
for conditionIndex=1:numel(cfg.Ncodeword)
    nCodeword=cfg.Ncodeword(conditionIndex);conditionSeed=cfg.miniMasterSeed+100000*nCodeword;
    for packetIndex=1:cfg.miniPacketCountPerCondition
        packetSeed=conditionSeed+packetIndex;rng(packetSeed,'twister');packet=auditQualityAwareMiniPacket(cfg,nCodeword);packetCursor=packetCursor+1;
        legacy=auditQualityAwareLegacyCausalEstimates(cfg,packet);online=struct('pilotObservation',packet.obs,'receivedData',packet.y,'dataSubcarriers',cfg.data,'validDataMask',packet.validReMask,'noiseVar',cfg.noiseVar,'rho',cfg.rho);
        quality=auditQualityAwareProposedCausalEstimates(cfg,online);
        estimates={legacy.Hbase,legacy.Hold,legacy.HfixedRadius2,quality.channelEstimates{2},quality.channelEstimates{3},quality.channelEstimates{4},[],legacy.Horacle,packet.H};
        estimationTimes=[legacy.baseAudit.baseEstimationTimeSec legacy.baseAudit.proposedEstimationTimeSec legacy.fixedAudit.runtimeSeconds quality.branchRuntimeSeconds(2:4).' 0 legacy.oracleAudit.runtimeSeconds 0];
        solverFailureOverrides=[NaN 0 legacy.fixedAudit.solverFailureCount quality.stateAudits{2}.solverFailureCount quality.stateAudits{3}.solverFailureCount quality.stateAudits{4}.solverFailureCount NaN legacy.oracleAudit.solverFailureCount NaN];
        for methodIndex=1:methodCount
            try
                metric=auditQualityAwareMiniDecode(cfg,packet,estimates{methodIndex},estimationTimes(methodIndex),covariance);
            catch exception
                error('Mini failed: payloadSymbols=%d packetIndex=%d method=%s symbolIndex=NaN subcarrierIndex=NaN selectedRadius=NaN. %s',packet.Npayload,packetIndex,methods(methodIndex),exception.message);
            end
            if methodIndex~=7,metric.solverFailureCount=solverFailureOverrides(methodIndex);end
            metric.payloadSymbols=packet.Npayload;metric.nCodeword=nCodeword;metric.packetIndex=packetIndex;metric.method=methods(methodIndex);metric=localAttachHashes(metric,packet.hashes);
            methodCursor=methodCursor+1;packetRows{methodCursor}=struct2table(metric,'AsArray',true);
            hashRows{methodCursor}=localHashRow(packet,packetIndex,methods(methodIndex),conditionSeed,packetSeed);
        end
        qualityIndices=[2 3 4];qualityNames=methods(4:6);
        for index=1:3,mechanismCursor=mechanismCursor+1;mechanismRows{mechanismCursor}=localMechanismRow(packet.Npayload,packetIndex,qualityNames(index),quality.stateAudits{qualityIndices(index)});end
    end
end
packetTable=vertcat(packetRows{:});packetTable=packetTable(:,schema.packet);pairingTable=vertcat(hashRows{:});mechanismTable=vertcat(mechanismRows{:});
localAssertPairing(pairingTable,methodCount);summaryTable=localSummary(packetTable);pairedTable=localPaired(packetTable);
writetable(packetTable,fullfile(outputDirectory,'quality_aware_mini_packet_level.csv'));writetable(summaryTable,fullfile(outputDirectory,'quality_aware_mini_summary.csv'));writetable(pairedTable,fullfile(outputDirectory,'quality_aware_mini_paired_statistics.csv'));writetable(pairingTable,fullfile(outputDirectory,'quality_aware_mini_pairing_hashes.csv'));
writetable(mechanismTable,fullfile(outputDirectory,'quality_aware_window_selection_audit.csv'));
writetable(mechanismTable(:,{'payloadSymbols','packetIndex','method','meanRdaTrace','medianRdaTrace','p95RdaTrace','minimumRdaTrace','maximumRdaTrace','meanNormalizedNis','medianNormalizedNis','p95NormalizedNis','maximumNormalizedNis','meanDecisionInflation','medianDecisionInflation','p95DecisionInflation','meanNisInflation','p95NisInflation'}),fullfile(outputDirectory,'quality_aware_rda_distribution_audit.csv'));
writetable(mechanismTable(:,{'payloadSymbols','packetIndex','method','noCandidateCount','innovationRejectCount','candidateCountBeforeInnovation','candidateCountAfterInnovation','innovationRejectRate','eigenFloorAppliedCount','solverFailureCount','covarianceNonPsdCount'}),fullfile(outputDirectory,'quality_aware_rejection_reason_audit.csv'));
totalWallTimeSec=toc(wall);localWriteReport(outputDirectory,cfg,packetTable,totalWallTimeSec,preflight);
result=struct('dryRun',false,'randomPhysicalPacketCount',packetCursor,'cfg',cfg,'methods',methods, ...
    'packetTable',packetTable,'summaryTable',summaryTable,'pairedTable',pairedTable, ...
    'pairingTable',pairingTable,'mechanismTable',mechanismTable,'preflight',preflight,'outputDirectory',outputDirectory);
end

function tables=localDryTables(schema)
names=fieldnames(schema);tables=struct();for i=1:numel(names),tables.(names{i})=cell2table(cell(0,numel(schema.(names{i}))),'VariableNames',schema.(names{i}));end
end
function pass=localSchemaPass(tables,schema)
names=fieldnames(schema);pass=true;for i=1:numel(names),pass=pass&&isequal(tables.(names{i}).Properties.VariableNames,schema.(names{i}));end
end
function metric=localAttachHashes(metric,hashes)
names=fieldnames(hashes);for i=1:numel(names),metric.(names{i})=hashes.(names{i});end
end
function T=localHashRow(packet,packetIndex,method,conditionSeed,packetSeed)
h=packet.hashes;T=table(packet.Npayload,packet.nCodeword,packetIndex,method,conditionSeed,packetSeed,h.informationBitsHash,h.transmitBitsHash,h.codedBitsHash,h.qamSymbolsHash,h.paddingMaskHash,h.channelHash,h.noiseHash,h.receivedSignalHash,h.pilotObservationHash,'VariableNames',auditQualityAwareMiniSchema().hash);
end
function T=localMechanismRow(payloadSymbols,packetIndex,method,audit)
radius=audit.selectedRadiusCount;radiusRate=radius/max(sum(radius),1);cursor=audit.candidateAuditCursor;rda=audit.rdaTrace(1:cursor);nis=audit.normalizedNis(1:cursor);decision=audit.decisionInflation(1:cursor);nisInflation=audit.nisInflation(1:cursor);
values={payloadSymbols,packetIndex,method,radius(1),radius(2),radius(3),radiusRate(1),radiusRate(2),radiusRate(3),audit.noCandidateCount,audit.innovationRejectCount,audit.candidateCountBeforeInnovation,audit.candidateCountAfterInnovation,audit.innovationRejectCount/max(audit.candidateCountBeforeInnovation,1),localStat(rda,'mean'),localStat(rda,'median'),localPercentile(rda,.95),localStat(rda,'min'),localStat(rda,'max'),localStat(nis,'mean'),localStat(nis,'median'),localPercentile(nis,.95),localStat(nis,'max'),localStat(decision,'mean'),localStat(decision,'median'),localPercentile(decision,.95),localStat(nisInflation,'mean'),localPercentile(nisInflation,.95),audit.eigenFloorAppliedCount,audit.solverFailureCount,audit.covarianceNonPsdCount,nnz(audit.daUpdateCount),audit.pilotUpdateCount};
T=cell2table(values,'VariableNames',auditQualityAwareMiniSchema().mechanism);
end
function value=localStat(data,kind),data=data(isfinite(data));if isempty(data),value=NaN;else,value=feval(kind,data);end,end
function value=localPercentile(data,p),data=sort(data(isfinite(data)));if isempty(data),value=NaN;return;end;position=1+(numel(data)-1)*p;lo=floor(position);hi=ceil(position);value=data(lo)+(position-lo)*(data(hi)-data(lo));end
function localAssertPairing(T,methodCount)
keys=unique(T(:,{'payloadSymbols','packetIndex'}),'rows');hashes=auditQualityAwareMiniSchema().hash(7:end);
for i=1:height(keys),rows=T(T.payloadSymbols==keys.payloadSymbols(i)&T.packetIndex==keys.packetIndex(i),:);assert(height(rows)==methodCount);for j=1:numel(hashes),value=rows.(hashes{j});assert(all(value==value(1)),'Pairing mismatch in %s.',hashes{j});end,end
end
function T=localSummary(R)
groups=unique(R(:,{'payloadSymbols','method'}),'rows');rows=cell(height(groups),1);
for i=1:height(groups),part=R(R.payloadSymbols==groups.payloadSymbols(i)&R.method==groups.method(i),:);total=sum(part.totalCodewordCount);passed=sum(part.passedCodewordCount);rows{i}=table(groups.payloadSymbols(i),groups.method(i),height(part),mean(part.csiNmse),median(part.csiNmse),mean(part.preLdpcBer),median(part.preLdpcBer),total,passed,passed/max(total,1),mean(part.payloadGoodputMbps),mean(part.runtimeSeconds),median(part.runtimeSeconds),nnz(part.hasNaN),nnz(part.hasInf),sum(part.futureSymbolReadCount),sum(part.testTruthOnlineUseCount),'VariableNames',auditQualityAwareMiniSchema().summary);end
T=vertcat(rows{:});
end
function T=localPaired(R)
comparisons=["OldMinFeasibleCausal_EP","BaseKalmanCausal_EP";"FixedRadius2Causal_EP","OldMinFeasibleCausal_EP";"QualityWindowOnlyCausal_EP","OldMinFeasibleCausal_EP";"AdaptiveRdaFixedR2Causal_EP","FixedRadius2Causal_EP";"QualityAwareLocalDAKalmanCausal_EP","OldMinFeasibleCausal_EP";"QualityAwareLocalDAKalmanCausal_EP","FixedRadius2Causal_EP";"QualityAwareLocalDAKalmanCausal_EP","BaseKalmanCausal_EP";"QualityAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted";"QualityAwareLocalDAKalmanCausal_EP","OracleDataAidedCausal_EP"];
metrics=["csiNmse","preLdpcBer","blockErrorRate","codewordPassRate","payloadGoodputMbps","runtimeSeconds"];higher=[false false false true true false];rows=cell(2*size(comparisons,1)*numel(metrics),1);cursor=0;
for payload=unique(R.payloadSymbols).',for comparison=1:size(comparisons,1),for metric=1:numel(metrics),a=sortrows(R(R.payloadSymbols==payload&R.method==comparisons(comparison,1),:),'packetIndex');b=sortrows(R(R.payloadSymbols==payload&R.method==comparisons(comparison,2),:),'packetIndex');delta=a.(metrics(metric))-b.(metrics(metric));tolerance=1e-15;if higher(metric),win=nnz(delta>tolerance);loss=nnz(delta<-tolerance);else,win=nnz(delta<-tolerance);loss=nnz(delta>tolerance);end;tie=numel(delta)-win-loss;cursor=cursor+1;rows{cursor}=table(payload,comparisons(comparison,1),comparisons(comparison,2),metrics(metric),numel(delta),mean(delta),median(delta),win,tie,loss,'VariableNames',auditQualityAwareMiniSchema().paired);end,end,end
T=vertcat(rows{1:cursor});
end
function localWriteReport(out,cfg,rows,wall,preflight)
file=fopen(fullfile(out,'quality_aware_mini_run_report.txt'),'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));fprintf(file,'Quality-aware paired Mini. Diagnostic sample only; no significance claim.\nseed=%d SNRdB=%g fdHz=%g Ncodeword=%s Npayload=%s packetsPerCondition=%d methods=%s\nphysicalPackets=%d methodRows=%d measuredWallTimeSec=%.9g\nfutureReadTotal=%g truthUseTotal=%g hasNaN=%d hasInf=%d\npreflightDeterministic=%d protectedHashes=%d MJCD/OJCD relativeDifference=%.17g\nEach quality branch runtime is its own measured prediction/pilot, decision, candidate, fusion time plus its own EP/LDPC decode time. Hashes are copied from one shared packetData object. Padding REs are excluded by validReMask.\n',cfg.miniMasterSeed,cfg.SNRdB,cfg.fdHz,mat2str(cfg.Ncodeword),mat2str(cfg.Npayload),cfg.miniPacketCountPerCondition,strjoin(cfg.miniMethods,','),height(rows)/numel(cfg.miniMethods),height(rows),wall,sum(rows.futureSymbolReadCount),sum(rows.testTruthOnlineUseCount),nnz(rows.hasNaN),nnz(rows.hasInf),preflight.deterministicReportsPass,preflight.protectedHashesPass,preflight.mjcdOjcdRelativeDifference);
end
