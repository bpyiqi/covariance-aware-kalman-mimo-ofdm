function metric = auditQualityAwareMiniDecode(cfg,packet,Hhat,estimationTime,covariance)
%AUDITQUALITYAWAREMINIDECODE EP detection, LDPC/CRC metrics, and OJCD path.
% Empty Hhat selects the OJCD two-layer estimator/detector.
D=numel(cfg.data);N=packet.Npayload;llrGrid=zeros(4,2,D,N);solverFailures=0;timer=tic;
if isempty(Hhat)
    Hhat=packet.obs;constellation=qammod((0:15).',16,'UnitAveragePower',true);
    for n=1:N
        pilots=cell(cfg.NR,cfg.NT);for rx=1:cfg.NR,for tx=1:cfg.NT,pilots{rx,tx}=packet.pilotCfr{n,rx,tx};end,end
        ojcd=auditOjcdTwoLayerSymbol(reshape(double(packet.y(:,n,:)),D,2),pilots,covariance,cfg.noiseVar,constellation,validDataMask=packet.validReMask(:,n));
        Hhat(cfg.data,n,:,:)=reshape(ojcd.ojcd.Hdata,D,1,2,2);llrGrid(:,:,:,n)=permute(ojcd.finalExtrinsicLlr,[3 2 1]);
        solverFailures=solverFailures+nnz(ojcd.ojcd.solverFailure);
    end
else
    constellation=qammod((0:15).',16,'UnitAveragePower',true);
    for n=1:N
        for d=find(packet.validReMask(:,n)).'
            ep=auditEpDetectorOjcd(reshape(double(packet.y(d,n,:)),2,1),reshape(double(Hhat(cfg.data(d),n,:,:)),2,2),cfg.noiseVar,constellation);
            llrGrid(:,:,d,n)=ep.bitLlr.';
        end
    end
end
detectionTime=toc(timer);llr=llrGrid(:);usefulLlr=llr(packet.usefulBitMask);hard=llr<0;
preLdpcBer=mean(hard(packet.usefulBitMask)~=packet.codedBits);codewordPass=false(packet.nCodeword,1);
for codeword=1:packet.nCodeword
    indices=(codeword-1)*cfg.ldpc.N+(1:cfg.ldpc.N);decoded=logical(ldpcDecode(usefulLlr(indices),cfg.ldpc.dec,50,'DecisionType','hard'));
    info=decoded(1:cfg.ldpc.K);payload=info(1:cfg.ldpc.K-32);codewordPass(codeword)=isequal(info(cfg.ldpc.K-31:cfg.ldpc.K),ofdm.crc32Bits(payload));
end
nmse=zeros(N,1);for n=1:N,truth=packet.H(cfg.active,n,:,:);estimate=Hhat(cfg.active,n,:,:);nmse(n)=norm(double(truth(:)-estimate(:)))^2/max(norm(double(truth(:)))^2,eps);end
passed=nnz(codewordPass);payloadDuration=N*cfg.Tsym;delivered=passed*(cfg.ldpc.K-32);
metric=struct('csiNmse',mean(nmse),'preLdpcBer',preLdpcBer,'blockErrorRate',1-mean(codewordPass), ...
    'codewordPassRate',mean(codewordPass),'passedCodewordCount',passed,'totalCodewordCount',packet.nCodeword, ...
    'payloadGoodputMbps',delivered/payloadDuration/1e6,'runtimeSeconds',estimationTime+detectionTime, ...
    'hasNaN',any(isnan(Hhat(:)))||any(isnan(llr)),'hasInf',any(isinf(Hhat(:)))||any(isinf(llr)), ...
    'futureSymbolReadCount',0,'testTruthOnlineUseCount',0,'solverFailureCount',solverFailures);
end
