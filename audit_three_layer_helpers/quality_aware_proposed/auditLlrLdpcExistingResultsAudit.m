function result=auditLlrLdpcExistingResultsAudit(root)
%AUDITLLRLDPCEXISTINGRESULTSAUDIT Read-only frozen-result anomaly inventory.
source=fullfile(root,'results_three_layer_validation','covariance_aware_snr_paired_localization20_seed20260725');
out=fullfile(root,'results_three_layer_validation','covariance_aware_llr_ldpc_existing_results_audit_v1');
required=["paired_localization_packet_level.csv","paired_localization_summary.csv","paired_localization_trend_audit.csv","paired_localization_manifest.txt","COMPLETE"];
assert(all(isfile(fullfile(source,required))));assert(exist(out,'dir')~=7,'Refusing to overwrite diagnostic directory: %s',out);mkdir(out);
S=readtable(fullfile(source,'paired_localization_summary.csv'),'TextType','string');methods=unique(S.method,'stable');rows=cell(height(S),1);cursor=0;target=.1;
for m=1:numel(methods)
    x=sortrows(S(S.method==methods(m),:),'targetSnrDb');warning=any(diff(x.codewordBler)>1e-12);
    for i=1:height(x)
        cursor=cursor+1;
        if i==1
            pre=false;evm=false;nmse=false;reverse=false;
        else
            pre=x.meanPreLdpcBer(i)<x.meanPreLdpcBer(i-1)&&x.codewordBler(i)>x.codewordBler(i-1);
            evm=x.meanSoftEvm(i)<x.meanSoftEvm(i-1)&&x.codewordBler(i)>x.codewordBler(i-1);
            nmse=x.meanAvgCsiNmse(i)<x.meanAvgCsiNmse(i-1)&&x.codewordBler(i)>x.codewordBler(i-1);
            reverse=x.codewordBler(i-1)<target&&x.codewordBler(i)>target;
        end
        rows{cursor}=table(x.method(i),x.targetSnrDb(i),x.meanPreLdpcBer(i),x.meanSoftEvm(i),x.meanAvgCsiNmse(i), ...
            x.codewordBler(i),x.wholePayloadBler(i),x.meanGoodputMbps(i),pre,evm,nmse,reverse,warning, ...
            'VariableNames',{'method','targetSnrDb','preLdpcBer','softEvm','avgCsiNmse','codewordBler', ...
            'wholePayloadBler','goodputMbps','preBerImprovesButBlerWorsens','evmImprovesButBlerWorsens', ...
            'nmseImprovesButBlerWorsens','reverseTargetCrossing','monotonicityWarning'});
    end
end
A=vertcat(rows{1:cursor});writetable(A,fullfile(out,'llr_ldpc_anomaly_summary.csv'));
[directional,crossings]=auditDirectionalBlerBracketAudit(S,methods,target);
writetable(directional,fullfile(out,'llr_ldpc_directional_bracket_audit.csv'));writetable(crossings,fullfile(out,'llr_ldpc_all_raw_crossings.csv'));
auditWriteLlrLdpcSignalPath(fullfile(out,'llr_ldpc_signal_path_audit.txt'),root);
f=fopen(fullfile(out,'llr_ldpc_anomaly_report.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'Read-only audit of %s.\nNo source result was modified.\n',source);
fprintf(f,'Rows=%d; methods=%d; pre-BER-improves/BLER-worsens flags=%d; EVM flags=%d; NMSE flags=%d; reverse target crossings=%d.\n',height(A),numel(methods),nnz(A.preBerImprovesButBlerWorsens),nnz(A.evmImprovesButBlerWorsens),nnz(A.nmseImprovesButBlerWorsens),nnz(A.reverseTargetCrossing));
fprintf(f,'The observed raw codeword BLER is seriously nonmonotonic even for PerfectCSI. It cannot be used for an SNR threshold, interpolation, or link-margin claim until LLR/mapping/decoder diagnostics are resolved.\n');
result=struct('outputDirectory',out,'rows',height(A),'reverseCrossings',nnz(A.reverseTargetCrossing));
fprintf('LLR/LDPC existing-results audit PASS: rows=%d reverseCrossings=%d output=%s\n',height(A),result.reverseCrossings,out);
end
