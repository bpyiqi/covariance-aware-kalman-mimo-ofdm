function result=auditCovarianceAwareSnrLocalization10Smoke(root)
%AUDITCOVARIANCEAWARESNRLOCALIZATION10SMOKE One deterministic five-method artifact smoke.
cfg=auditCovarianceAwareSnrLocalization10Config(root);cfg.masterSeed=cfg.smokeSeed;cfg.bootstrapSeed=cfg.smokeSeed+1;
cfg.SNRdBGrid=20;cfg.packetCountPerSnr=1;cfg.experimentName="covariance_aware_snr_localization10_artifact_smoke";
temporary=[tempname '_snr_localization10_smoke'];mkdir(temporary);cleanup=onCleanup(@()localCleanup(temporary));
result=auditCovarianceAwareSnrLocalization10RunCore(cfg,temporary,testMode=true);
assert(height(result.packetTable)==5,'One-packet SNR smoke must produce five method rows.');
assert(isscalar(unique(result.packetTable.sharedHashH))&&isscalar(unique(result.packetTable.sharedHashY)));
schema=auditCovarianceAwareSnrLocalization10Schema();required=[string(struct2cell(schema.files)); ...
    "snr_localization_codeword_bler.fig";"snr_localization_codeword_bler.png";"snr_localization_codeword_bler.pdf"];
assert(all(isfile(fullfile(temporary,required))),'SNR artifact smoke is missing required files.');
localTinyTests();
fprintf('SNR localization10 artifact smoke PASS: rows=5, physicalPackets=1, smokeSeed=%d, formal masterSeed not consumed.\n',cfg.masterSeed);
end
function localTinyTests()
methods=["BaseKalmanCausal_EP","CovarianceAwareLocalDAKalmanCausal_EP","OJCD_LMMSE_EP_Adapted","PerfectCSI_EP"];
snr=repmat([16;18;20],numel(methods),1);method=repelem(methods.',3);bler=repmat([.3;.1;0],numel(methods),1);
S=table(snr,method,bler,'VariableNames',{'SNRdB','method','codewordBler'});
B=auditCovarianceAwareSnrBlerBrackets(S,methods,.1);assert(all(B.bracketFound)&all(B.lowerSnrDb==16)&all(B.upperSnrDb==18));
decoded=[30;30];errors=[3;0];assert(sum(errors)/sum(decoded)==.05);
fprintf('SNR BLER aggregation and target-bracket tiny tests PASS.\n');
end
function localCleanup(path),if exist(path,'dir'),rmdir(path,'s');end,end
