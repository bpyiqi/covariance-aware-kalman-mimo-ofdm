function result=auditCovarianceAwareSnrPairedLocalization20Smoke(root)
%AUDITCOVARIANCEAWARESNRPAIREDLOCALIZATION20SMOKE Three-SNR one-scenario CRN smoke.
cfg=auditCovarianceAwareSnrPairedLocalization20Config(root);cfg.masterSeed=cfg.smokeSeed;cfg.bootstrapSeed=cfg.smokeSeed+1;
cfg.SNRdBGrid=[20 24 28];cfg.scenarioCount=1;cfg.experimentName="covariance_aware_snr_paired_localization20_artifact_smoke";
temporary=[tempname '_paired_localization20_smoke'];mkdir(temporary);cleanup=onCleanup(@()localCleanup(temporary));
result=auditCovarianceAwareSnrPairedLocalization20RunCore(cfg,temporary,testMode=true);T=result.packetTable;
assert(height(T)==15&&isscalar(unique(T.scenarioHashH))&&isscalar(unique(T.scenarioHashTxBits)));
assert(isscalar(unique(T.scenarioHashQam))&&isscalar(unique(T.scenarioHashUnitNoise)));
assert(numel(unique(T.sharedHashY))==3&&max(abs(T.realizedSnrDb-T.targetSnrDb))<=cfg.realizedSnrToleranceDb);
for snr=cfg.SNRdBGrid,x=T(T.targetSnrDb==snr,:);assert(height(x)==5&&isscalar(unique(x.sharedHashY)));end
maxError=max(abs(T.realizedSnrDb-T.targetSnrDb));clear cleanup;assert(exist(temporary,'dir')~=7,'Smoke temporary directory was not cleaned.');
fprintf('paired localization20 artifact smoke PASS: rows=15, shared H/bits/QAM/unitNoise=true, uniqueY=3, maxRealizedSnrErrorDb=%.6g, smokeSeed=%d.\n',maxError,cfg.masterSeed);
end
function localCleanup(path),if exist(path,'dir'),rmdir(path,'s');end,end
