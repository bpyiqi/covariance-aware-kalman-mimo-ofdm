function metric = auditMechanismOfflineDetectionMetrics(cfg,online,Hhat,Htrue,qamTrue,codedBits,validMask)
%AUDITMECHANISMOFFLINEDETECTIONMETRICS Post-online truth-only diagnostics.
timer=tic;N=size(Htrue,2);D=numel(cfg.data);hardBits=online.llr<0;preLdpcBer=mean(hardBits(validMaskUseful(validMask,cfg))~=codedBits);codewordPass=online.codewordPass;passed=nnz(codewordPass);
activeError=Hhat(cfg.active,:,:,:)-Htrue(cfg.active,:,:,:);activeTruth=Htrue(cfg.active,:,:,:);csiNmse=sum(abs(activeError(:)).^2)/max(sum(abs(activeTruth(:)).^2),eps);
streamNmse=zeros(1,2);for stream=1:2,e=Hhat(cfg.data,:,:,stream)-Htrue(cfg.data,:,:,stream);t=Htrue(cfg.data,:,:,stream);mask=repmat(validMask,1,1,2);streamNmse(stream)=sum(abs(e(mask)).^2)/max(sum(abs(t(mask)).^2),eps);end
reError=nan(D,N);gain=nan(D,N);for n=1:N,for d=find(validMask(:,n)).',e=squeeze(Hhat(cfg.data(d),n,:,:)-Htrue(cfg.data(d),n,:,:));t=squeeze(Htrue(cfg.data(d),n,:,:));reError(d,n)=norm(e,'fro')^2/max(norm(t,'fro')^2,eps);gain(d,n)=norm(t,'fro')^2;end,end
validErrors=reError(validMask);validGain=gain(validMask);threshold=auditDeterministicPercentile(validGain,.10);deep=validGain<=threshold;errorEnergy=validErrors.*validGain;deepError=sum(errorEnergy(deep));allError=sum(errorEnergy);deepTruth=sum(validGain(deep));nonTruth=sum(validGain(~deep));
softEvm=zeros(1,2);hardEvm=zeros(1,2);sinrDb=zeros(1,2);for stream=1:2,truth=squeeze(qamTrue(stream,:,:));soft=squeeze(online.softSymbols(stream,:,:));hard=squeeze(online.hardSymbols(stream,:,:));den=sum(abs(truth(validMask)).^2);softError=sum(abs(soft(validMask)-truth(validMask)).^2);hardError=sum(abs(hard(validMask)-truth(validMask)).^2);softEvm(stream)=sqrt(softError/max(den,eps));hardEvm(stream)=sqrt(hardError/max(den,eps));sinrDb(stream)=10*log10(den/max(softError,eps));end
variance=online.posteriorVariance(repmat(reshape(validMask,1,D,N),2,1,1));payloadDuration=N*cfg.Tsym;
metric=struct('csiNmse',csiNmse,'preLdpcBer',preLdpcBer,'blockErrorRate',1-mean(codewordPass),'codewordPassRate',mean(codewordPass),'passedCodewordCount',passed,'totalCodewordCount',numel(codewordPass),'payloadGoodputMbps',passed*(cfg.ldpc.K-32)/payloadDuration/1e6, ...
    'stream1CsiNmse',streamNmse(1),'stream2CsiNmse',streamNmse(2),'worstStreamCsiNmse',max(streamNmse),'bestStreamCsiNmse',min(streamNmse),'streamNmseImbalanceDb',10*log10(max(streamNmse)/max(min(streamNmse),eps)), ...
    'medianReNormalizedError',median(validErrors),'p90ReNormalizedError',auditDeterministicPercentile(validErrors,.90),'p95ReNormalizedError',auditDeterministicPercentile(validErrors,.95),'p99ReNormalizedError',auditDeterministicPercentile(validErrors,.99),'maximumReNormalizedError',max(validErrors), ...
    'deepFadeReCount',nnz(deep),'deepFadeCsiNmse',deepError/max(deepTruth,eps),'nonDeepFadeCsiNmse',sum(errorEnergy(~deep))/max(nonTruth,eps),'deepFadeErrorShare',deepError/max(allError,eps), ...
    'stream1SoftEvmRms',softEvm(1),'stream2SoftEvmRms',softEvm(2),'worstStreamSoftEvmRms',max(softEvm),'softEvmRms',sqrt(mean(softEvm.^2)),'stream1HardEvmRms',hardEvm(1),'stream2HardEvmRms',hardEvm(2),'worstStreamHardEvmRms',max(hardEvm), ...
    'stream1EvmEffectiveSinrDb',sinrDb(1),'stream2EvmEffectiveSinrDb',sinrDb(2),'worstStreamEvmEffectiveSinrDb',min(sinrDb),'meanEvmEffectiveSinrDb',-20*log10(max(sqrt(mean(softEvm.^2)),sqrt(eps))),'evmEffectiveSinrDb',-20*log10(max(sqrt(mean(softEvm.^2)),sqrt(eps))), ...
    'meanPosteriorVariance',mean(variance),'medianPosteriorVariance',median(variance),'p95PosteriorVariance',auditDeterministicPercentile(variance,.95),'offlineAuditRuntimeSeconds',toc(timer));
end

function mask=validMaskUseful(validRe,cfg)
resourceMask=repmat(reshape(validRe,1,numel(cfg.data),size(validRe,2)),cfg.bitsPerQam*cfg.NT,1,1);mask=resourceMask(:);
end
