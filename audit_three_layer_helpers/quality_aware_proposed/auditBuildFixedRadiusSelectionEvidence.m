function result = auditBuildFixedRadiusSelectionEvidence(root)
%AUDITBUILDFIXEDRADIUSSELECTIONEVIDENCE Read-only development-set evidence.
source=fullfile(root,'results_three_layer_validation','quality_aware_proposed_diagnostic20_seed20260720');
out=fullfile(root,'results_three_layer_validation','covariance_aware_method_freeze_audit');
assert(~exist(fullfile(out,'fixed_radius_selection_evidence.txt'),'file'),'Refusing to overwrite fixed-radius evidence.');
packet=readtable(fullfile(source,'quality_aware_diagnostic20_packet_level.csv'),'TextType','string');
paired=readtable(fullfile(source,'quality_aware_diagnostic20_paired_statistics.csv'),'TextType','string');
methods=["FixedRadius1Causal_EP","FixedRadius2Causal_EP","FixedRadius3Causal_EP"];packet=packet(ismember(packet.method,methods),:);
if ~exist(out,'dir'),mkdir(out);end
writetable(packet,fullfile(out,'fixed_radius_development_packet_level.csv'));
summary=groupsummary(packet,{'payloadSymbols','method'},{'mean','median'},{'csiNmse','preLdpcBer','codewordPassRate','payloadGoodputMbps'});writetable(summary,fullfile(out,'fixed_radius_development_summary.csv'));
paired=paired((paired.methodA=="FixedRadius3Causal_EP"&ismember(paired.methodB,methods(1:2))),:);writetable(paired,fullfile(out,'fixed_radius_development_paired_statistics.csv'));
file=fopen(fullfile(out,'fixed_radius_selection_evidence.txt'),'w','n','UTF-8');cleanup=onCleanup(@()fclose(file));
fprintf(file,'Development-set structural selection evidence only. Candidate set {1,2,3} was fixed before diagnostic20. Source seed=20260720; this is not independent validation.\n');
fprintf(file,'FixedRadius3 was frozen from development NMSE/BER composite evidence. It is not claimed as universally optimal. Independent validation uses seed=20260721 and must not alter radius.\n');
fprintf(file,'Delta convention: R3-comparator; negative NMSE/BER is better, positive pass rate/goodput is better.\n');
result=struct('outputDirectory',out,'rows',height(packet),'randomPhysicalPacketCount',0);
end
