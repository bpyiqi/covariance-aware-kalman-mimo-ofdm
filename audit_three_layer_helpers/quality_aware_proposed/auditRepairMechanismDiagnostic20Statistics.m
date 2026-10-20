function result = auditRepairMechanismDiagnostic20Statistics(root)
%AUDITREPAIRMECHANISMDIAGNOSTIC20STATISTICS Read-only v2 postprocessor.
source=fullfile(root,'results_three_layer_validation','quality_aware_mechanism_diagnostic20_seed20260720');
out=fullfile(root,'results_three_layer_validation','quality_aware_mechanism_diagnostic20_postprocessed_v2');
assert(exist(fullfile(source,'quality_aware_mechanism_packet_level.csv'),'file')==2,'Mechanism packet table is missing.');
assert(~exist(fullfile(out,'quality_aware_mechanism_paired_statistics_v2.csv'),'file'),'Refusing to overwrite v2 postprocessing output.');
if ~exist(out,'dir'),mkdir(out);end
schema=auditQualityAwareMechanismSchema();packet=readtable(fullfile(source,'quality_aware_mechanism_packet_level.csv'),'TextType','string');
paired=auditBuildMechanismPairedStatistics(packet,schema);
rejectionSource=readtable(fullfile(source,'quality_aware_mechanism_rejection_audit.csv'),'TextType','string');
rejection=auditAggregateMechanismRejections(rejectionSource,schema);
summary=localSummary(packet);writetable(paired,fullfile(out,'quality_aware_mechanism_paired_statistics_v2.csv'));
writetable(rejection,fullfile(out,'quality_aware_mechanism_rejection_audit_v2.csv'));writetable(summary,fullfile(out,'quality_aware_mechanism_summary_v2.csv'));
file=fopen(fullfile(out,'mechanism_diagnostic20_postprocessing_v2_report.txt'),'w','n','UTF-8');cleanup=onCleanup(@()fclose(file));
fprintf(file,'Read-only postprocessing of %s\nNo random packets were generated and no historical source file was overwritten.\n',source);
fprintf(file,'paired rows=%d; unique paired keys=%d. rejection rows=%d; Base rows=%d.\n',height(paired),height(unique(paired(:,{'payloadSymbols','methodA','methodB','metric'}),'rows')),height(rejection),nnz(rejection.method=="BaseKalmanCausal_EP"));
fprintf(file,'Aggregate EVM effective SINR is NaN because packet-level trueSymbolEnergy and softErrorEnergy were not retained. Median/quantile EVM-SINR remain available; no dB-average inversion was performed.\n');
result=struct('outputDirectory',out,'pairedRows',height(paired),'rejectionRows',height(rejection),'randomPhysicalPacketCount',0);
end

function T=localSummary(P)
keys=unique(P(:,{'payloadSymbols','method'}),'rows');cells=cell(height(keys),1);
for i=1:height(keys)
    x=P(P.payloadSymbols==keys.payloadSymbols(i)&P.method==keys.method(i),:);v=x.evmEffectiveSinrDb(isfinite(x.evmEffectiveSinrDb));
    cells{i}=table(keys.payloadSymbols(i),keys.method(i),height(x),mean(x.csiNmse),median(x.csiNmse),mean(x.preLdpcBer),median(x.preLdpcBer),sum(x.totalCodewordCount),sum(x.passedCodewordCount),sum(x.passedCodewordCount)/max(sum(x.totalCodewordCount),1),mean(x.payloadGoodputMbps),median(x.payloadGoodputMbps),median(x.softEvmRms),auditDeterministicPercentile(v,.25),median(v),auditDeterministicPercentile(v,.75),min(v),max(v),NaN,'VariableNames',{'payloadSymbols','method','packetCount','meanCsiNmse','medianCsiNmse','meanPreLdpcBer','medianPreLdpcBer','totalCodewords','passedCodewords','codewordPassRate','meanPayloadGoodputMbps','medianPayloadGoodputMbps','medianSoftEvmRms','p25EvmEffectiveSinrDb','medianEvmEffectiveSinrDb','p75EvmEffectiveSinrDb','minimumEvmEffectiveSinrDb','maximumEvmEffectiveSinrDb','aggregateEvmEffectiveSinrDb'});
end
T=vertcat(cells{:});
end
