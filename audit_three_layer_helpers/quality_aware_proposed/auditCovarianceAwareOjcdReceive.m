function result=auditCovarianceAwareOjcdReceive(cfg,packet,covariance,options)
%AUDITCOVARIANCEAWAREOJCDRECEIVE Collect frozen OJCD outputs for auditing.
arguments
    cfg struct
    packet struct
    covariance struct
    options.captureEpDiagnostics (1,1) logical = false
end
D=numel(cfg.data);N=packet.Npayload;constellation=qammod((0:15).',16,'UnitAveragePower',true);
Hhat=packet.obs;llrGrid=zeros(4,2,D,N);soft=complex(nan(2,D,N));hard=complex(nan(2,D,N));variance=nan(2,D,N);if options.captureEpDiagnostics,jcd1Diagnostics=cell(D,N);jcd2Diagnostics=cell(D,N);end;solverFailures=0;timer=tic;
for n=1:N
    pilots=cell(cfg.NR,cfg.NT);for rx=1:cfg.NR,for tx=1:cfg.NT,pilots{rx,tx}=packet.pilotCfr{n,rx,tx};end,end
    step=auditOjcdTwoLayerSymbol(reshape(double(packet.y(:,n,:)),D,2),pilots,covariance,cfg.noiseVar,constellation,validDataMask=packet.validReMask(:,n),captureEpDiagnostics=options.captureEpDiagnostics);
    Hhat(cfg.data,n,:,:)=reshape(step.ojcd.Hdata,D,1,2,2);llrGrid(:,:,:,n)=permute(step.finalExtrinsicLlr,[3 2 1]);soft(:,:,n)=step.jcd2PosteriorMean.';variance(:,:,n)=step.jcd2PosteriorVariance.';
    for d=find(packet.validReMask(:,n)).',bits=squeeze(step.finalExtrinsicLlr(d,:,:)).'<0;hard(:,d,n)=reshape(ofdm.qam16ModBits(double(bits(:))),2,1);end
    solverFailures=solverFailures+nnz(step.ojcd.solverFailure);
    if options.captureEpDiagnostics,jcd1Diagnostics(:,n)=step.jcd1EpDiagnostics;jcd2Diagnostics(:,n)=step.jcd2EpDiagnostics;end
end
onlineRuntime=toc(timer);llr=llrGrid(:);usefulLlr=llr(packet.usefulBitMask);codewordPass=false(packet.nCodeword,1);
for cw=1:packet.nCodeword,idx=(cw-1)*cfg.ldpc.N+(1:cfg.ldpc.N);decoded=logical(ldpcDecode(usefulLlr(idx),cfg.ldpc.dec,50,'DecisionType','hard'));info=decoded(1:cfg.ldpc.K);payload=info(1:cfg.ldpc.K-32);codewordPass(cw)=isequal(info(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payload));end
result=struct('Hhat',Hhat,'receiver',struct('llr',llr,'softSymbols',soft,'hardSymbols',hard,'posteriorVariance',variance,'codewordPass',codewordPass,'onlineRuntimeSeconds',onlineRuntime,'hasNaN',any(isnan(Hhat(:)))||any(isnan(llr)),'hasInf',any(isinf(Hhat(:)))||any(isinf(llr))),'solverFailureCount',solverFailures);
if options.captureEpDiagnostics,result.receiver.jcd1EpDiagnostics=jcd1Diagnostics;result.receiver.jcd2EpDiagnostics=jcd2Diagnostics;end
end
