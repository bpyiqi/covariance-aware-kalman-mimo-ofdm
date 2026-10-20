function artifacts=auditCovarianceAwareSnrLocalization10Finalize(cfg,out,T,testMode)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10FINALIZE Gate, aggregate, and publish localization artifacts.
schema=auditCovarianceAwareSnrLocalization10Schema();localGate(T,cfg,testMode);
S=localSummary(T);bracketMethods=["BaseKalmanCausal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
B=auditCovarianceAwareSnrBlerBrackets(S,bracketMethods,cfg.targetCodewordBler);H=localPairing(T);
writetable(T,fullfile(out,schema.files.packetLevel));writetable(S,fullfile(out,schema.files.summary));
writetable(B,fullfile(out,schema.files.brackets));writetable(H,fullfile(out,schema.files.pairing));
localManifest(cfg,out,schema);localConfig(cfg,out,schema);localRuntime(T,out,schema);localReport(cfg,out,S,B,schema);
if ~testMode||~isfield(cfg,'skipFiguresInTest')||~cfg.skipFiguresInTest,localFigures(cfg,out,S);end
save(fullfile(out,schema.files.resultsMat),'cfg','T','S','B','H','-v7.3');
artifacts=struct('summary',S,'brackets',B,'pairing',H);
end

function localGate(T,cfg,testMode)
expected=numel(cfg.SNRdBGrid)*cfg.packetCountPerSnr*numel(cfg.methods);if testMode,expected=height(T);end
assert(height(T)==expected,'Expected %d rows, found %d.',expected,height(T));
keys=unique(T(:,{'SNRdB','payloadSymbols','packetIndex'}),'rows');
for i=1:height(keys)
    x=T(T.SNRdB==keys.SNRdB(i)&T.payloadSymbols==keys.payloadSymbols(i)&T.packetIndex==keys.packetIndex(i),:);
    assert(height(x)==numel(cfg.methods)&&numel(unique(x.method))==numel(cfg.methods));
    names={'sharedHashH','sharedHashY','sharedHashTxBits','paddingBitHash','paddingSymbolHash','paddingReCount'};
    for j=1:numel(names),assert(isscalar(unique(x.(names{j}))),'Pairing mismatch in %s.',names{j});end
end
assert(~any(T.hasNaN)&~any(T.hasInf)&all(T.legacySecondPassUseCount==0)&all(T.withinSymbolDaFeedbackEvents==0));
assert(all(T.stateRestartsAfterSymbol1==0)&all(T.crossSubcarrierStatePropagationEvents==0)&all(T.repeatedPilotUseCount==0));
assert(all(T.rejectedTargetsWithDaUpdate==0)&all(T.paddingTargetsWithDaUpdate==0));
assert(all(T.maxPilotUpdatesPerTarget<=1)&all(T.maxDaUpdatesPerTarget<=1));
assert(all(T.solverFailureCount==0)&all(T.paddingDaUseCount==0)&all(T.sameSymbolFeedbackCount==0));
core={'avgCsiNmse','preLdpcBer','codewordPassRate','goodputMbps','softEvm','processingTimeSec'};
for i=1:numel(core),assert(all(isfinite(T.(core{i}))),'Nonfinite core metric %s.',core{i});end
end

function S=localSummary(T)
keys=unique(T(:,{'SNRdB','method'}),'rows');names=auditCovarianceAwareSnrLocalization10Schema().summary;rows=cell(height(keys),1);
for i=1:height(keys)
    x=T(T.SNRdB==keys.SNRdB(i)&T.method==keys.method(i),:);decoded=sum(x.decodedCodewordCount);errors=sum(x.codewordErrorCount);
    evm2=mean(x.softEvmSquared);rows{i}=table(keys.SNRdB(i),keys.method(i),height(x),decoded,errors, ...
        1-errors/decoded,errors/decoded,mean(x.codewordPass),1-mean(x.codewordPass), ...
        mean(x.avgCsiNmse),mean(x.preLdpcBer),mean(x.softEvm),10*log10(1/max(evm2,eps)), ...
        mean(x.goodputMbps),mean(x.processingTimeSec),'VariableNames',cellstr(names));
end
S=vertcat(rows{:});
end

function H=localPairing(T)
keys=unique(T(:,{'SNRdB','payloadSymbols','packetIndex'}),'rows');names=auditCovarianceAwareSnrLocalization10Schema().pairing;rows=cell(height(keys),1);
for i=1:height(keys)
    x=T(T.SNRdB==keys.SNRdB(i)&T.payloadSymbols==keys.payloadSymbols(i)&T.packetIndex==keys.packetIndex(i),:);
    fields={'conditionSeed','packetSeed','sharedHashH','sharedHashY','sharedHashTxBits','paddingBitHash','paddingSymbolHash','paddingReCount'};
    match=true;for j=1:numel(fields),match=match&&isscalar(unique(x.(fields{j})));end
    rows{i}=table(keys.SNRdB(i),keys.payloadSymbols(i),keys.packetIndex(i),x.conditionSeed(1),x.packetSeed(1), ...
        x.sharedHashH(1),x.sharedHashY(1),x.sharedHashTxBits(1),x.paddingBitHash(1),x.paddingSymbolHash(1), ...
        x.paddingReCount(1),match,'VariableNames',cellstr(names));
end
H=vertcat(rows{:});assert(all(H.allSharedHashesMatch));
end

function localFigures(cfg,out,S)
spec={"codewordBler","Codeword BLER","snr_localization_codeword_bler",true; ...
    "wholePayloadBler","Whole-payload BLER","snr_localization_whole_payload_bler",true; ...
    "meanAvgCsiNmse","CSI NMSE","snr_localization_csi_nmse",true; ...
    "meanPreLdpcBer","Pre-LDPC BER","snr_localization_pre_ldpc_ber",true; ...
    "meanSoftEvm","Soft EVM","snr_localization_soft_evm",false; ...
    "meanGoodputMbps","Goodput (Mbps)","snr_localization_goodput",false; ...
    "meanProcessingTimeSec","Processing time (s)","snr_localization_runtime",false};
methods=cfg.methods;colors=lines(numel(methods));labels=localLabels(methods);displayFloor=1e-3;
for q=1:size(spec,1)
    f=figure('Visible','off','Color','w','Position',[100 100 900 620]);ax=axes(f);hold(ax,'on'); %#ok<LAXES>
    for m=1:numel(methods)
        x=sortrows(S(S.method==methods(m),:),'SNRdB');y=x.(spec{q,1});
        if spec{q,4},plotY=max(y,displayFloor);else,plotY=y;end
        plot(ax,x.SNRdB,plotY,'-o','Color',colors(m,:),'LineWidth',1.3,'MarkerFaceColor',colors(m,:));
    end
    if spec{q,4},set(ax,'YScale','log');text(ax,.01,.02,sprintf('Display floor = %g; CSV retains true zeros.',displayFloor),'Units','normalized','FontSize',9);end
    grid(ax,'on');xlabel(ax,'SNR (dB)');ylabel(ax,spec{q,2});title(ax,spec{q,2}+" vs SNR");
    legend(ax,labels,'Location','best');subtitle(ax,'Localization scan: 10 physical packets and 30 codewords per SNR; not the final performance curve.');
    localExport(f,out,spec{q,3});close(f);
end
end
function labels=localLabels(methods)
labels=replace(methods,["BaseKalmanCausal_EP","FixedRadius3Causal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"],["Base","FixedR3","CovAware","OJCD","Perfect CSI"]);
end
function localExport(f,out,name)
savefig(f,fullfile(out,[char(name) '.fig']));exportgraphics(f,fullfile(out,[char(name) '.png']),'Resolution',600);
exportgraphics(f,fullfile(out,[char(name) '.pdf']),'ContentType','vector');
end

function localManifest(cfg,out,schema)
f=fopen(fullfile(out,schema.files.manifest),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,['experimentName=%s\nschemaVersion=%s\nmasterSeed=%d\nbootstrapSeed=%d\nSNRdBGrid=%s\nfdHz=%g\npayloadSymbols=%d\nnCodeword=%d\npacketCountPerSnr=%d\nmethods=%s\n' ...
    'conditionSeedFormula=masterSeed+10000*round(10*SNRdB)\npacketSeedFormula=conditionSeed+packetIndex\nindependentNoisePerSnr=true\n' ...
    'fixedRadius=3\nllrThreshold=2.5\nminEffectiveSamples=2\ngramRcondThreshold=0.001\nRDA=RLS\nparameterTuning=false\n'], ...
    cfg.experimentName,schema.version,cfg.masterSeed,cfg.bootstrapSeed,mat2str(cfg.SNRdBGrid),cfg.fdHz,cfg.Npayload,cfg.Ncodeword,cfg.packetCountPerSnr,strjoin(cfg.methods,','));
end
function localConfig(cfg,out,schema)
f=fopen(fullfile(out,schema.files.config),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'masterSeed=%d\nbootstrapSeed=%d\npayloadSymbols=%d\nsymbolsPerCodeword=%d\nSNRdBGrid=%s\nfdHz=%g\nrho=%.17g\nexpectedRows=%d\n', ...
    cfg.masterSeed,cfg.bootstrapSeed,cfg.Npayload,cfg.symbolsPerCodeword,mat2str(cfg.SNRdBGrid),cfg.fdHz,cfg.rho,numel(cfg.SNRdBGrid)*cfg.packetCountPerSnr*numel(cfg.methods));
end
function localRuntime(T,out,schema)
f=fopen(fullfile(out,schema.files.runtime),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'processingTimeSec contains method processing time per packet; aggregate wall-clock sharing is not inferred.\n');
keys=unique(T(:,{'SNRdB','method'}),'rows');for i=1:height(keys),x=T(T.SNRdB==keys.SNRdB(i)&T.method==keys.method(i),:);fprintf(f,'SNR=%g method=%s mean=%.6f median=%.6f sec\n',keys.SNRdB(i),keys.method(i),mean(x.processingTimeSec),median(x.processingTimeSec));end
end
function localReport(cfg,out,S,B,schema)
f=fopen(fullfile(out,schema.files.report),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'Coarse SNR localization scan; not a final performance curve and not a tuning experiment.\n');
fprintf(f,'Each SNR uses %d physical packets and %d decoded LDPC codewords per method. Primary threshold metric: codeword BLER. Whole-payload BLER is supplemental.\n',cfg.packetCountPerSnr,cfg.packetCountPerSnr*cfg.Ncodeword);
for i=1:height(B)
    if B.bracketFound(i)
        fprintf(f,'%s: BLER %.3f target bracketed by [%g dB, BLER %.4f] and [%g dB, BLER %.4f].\n',B.method(i),B.targetBler(i),B.lowerSnrDb(i),B.lowerBler(i),B.upperSnrDb(i),B.upperBler(i));
    else
        x=sortrows(S(S.method==B.method(i),:),'SNRdB');if all(x.codewordBler>cfg.targetCodewordBler),direction='higher';elseif all(x.codewordBler<cfg.targetCodewordBler),direction='lower';else,direction='a denser neighboring';end
        fprintf(f,'%s: target not bracketed; extend toward %s SNR without automatic extension.\n',B.method(i),direction);
    end
    if B.monotonicityWarning(i),fprintf(f,'  Raw coarse points are nonmonotonic; no point was deleted, smoothed, or interpolated.\n');end
end
fprintf(f,['\nInterpretation questions after this scan:\n' ...
    '1. Base-to-Perfect gap is described from codeword BLER, NMSE, BER, EVM, and goodput jointly.\n' ...
    '2. CovarianceAware-to-Base and CovarianceAware-to-OJCD trends require the full raw grid; ten packets per SNR are localization evidence only.\n' ...
    '3. Threshold brackets are intervals, not interpolated SNR thresholds.\n' ...
    '4. Entry into a 500-packet experiment requires intact gates, useful target bracketing, and no unexplained numerical failure.\n']);
end
