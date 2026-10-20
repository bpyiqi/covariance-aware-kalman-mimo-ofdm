function result=auditCovarianceAwareSnrLocalization10ReadonlyAudit(root)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10READONLYAUDIT Diagnose the frozen failed scan.
source=fullfile(root,'results_three_layer_validation','covariance_aware_snr_localization10_seed20260724');
out=fullfile(root,'results_three_layer_validation','covariance_aware_snr_localization10_failed_diagnostic_audit');
assert(isfile(fullfile(source,'COMPLETE'))&&isfile(fullfile(source,'snr_localization_packet_level.csv')));
assert(exist(out,'dir')~=7,'Refusing to overwrite old-localization diagnostic: %s',out);mkdir(out);
T=readtable(fullfile(source,'snr_localization_packet_level.csv'),'TextType','string');indices=unique(T.packetIndex);rows=cell(numel(indices),1);
for i=1:numel(indices)
    x=T(T.packetIndex==indices(i),:);snrCount=numel(unique(x.SNRdB));hCount=numel(unique(x.sharedHashH));
    txCount=numel(unique(x.sharedHashTxBits));rows{i}=table(indices(i),snrCount,hCount,txCount,hCount==snrCount&&txCount==snrCount, ...
        'VariableNames',{'packetIndex','snrPointCount','uniqueHHashCount','uniqueTxBitsHashCount','notCommonRandomNumbers'});
end
A=vertcat(rows{:});writetable(A,fullfile(out,'localization10_cross_snr_hash_audit.csv'));
f=fopen(fullfile(out,'localization10_failed_diagnostic_report.txt'),'w','n','UTF-8');assert(f>=0);c=onCleanup(@()fclose(f));
fprintf(f,'Read-only audit of frozen covariance_aware_snr_localization10_seed20260724.\n');
fprintf(f,'packetIndex groups=%d; every group has seven unique H hashes=%d; every group has seven unique Tx-bit hashes=%d.\n',height(A),all(A.uniqueHHashCount==7),all(A.uniqueTxBitsHashCount==7));
fprintf(f,'The old scan did not use common random numbers across SNR. Channel/data scenario variation is confounded with SNR, so this result is retained only as a failed localization diagnostic and must not be used as a formal SNR threshold.\n');
result=struct('groupCount',height(A),'allSevenH',all(A.uniqueHHashCount==7),'allSevenTxBits',all(A.uniqueTxBitsHashCount==7),'outputDirectory',out);
fprintf('old localization10 read-only audit PASS: groups=%d, sevenH=%d, sevenTxBits=%d.\n',result.groupCount,result.allSevenH,result.allSevenTxBits);
end

